# Gmail webhook contract

The seam between n8n (thin relay, watches a Gmail inbox) and Rails (all
decision logic) -- in **both** directions. Inbound: n8n calls Rails when
an email arrives. Outbound: Rails calls n8n when a human approves a
reply, so n8n can actually send it. n8n owns every real Gmail API call
either way (watching the inbox, sending mail) using the same credential;
Rails never holds Gmail OAuth itself. Every rule below lives in
`app/controllers/gmail_webhooks_controller.rb` or
`app/services/outbound_email_service.rb`, not in n8n's workflow config,
so it stays testable and reviewable in git.

## Inbound: n8n → Rails

### Endpoint

```
POST /webhooks/gmail/:webhook_token
```

### Auth

`:webhook_token` identifies **and** authenticates the organization in one
step — a random, unguessable per-organization secret
(`Organization#webhook_token`, via Rails' `has_secure_token`), the same
role a per-account webhook secret plays in Stripe or GitHub's webhooks.
There is no separate auth header. A token that doesn't match any
organization gets `401 Unauthorized`.

The organization is determined **only** by which token was used to call
this endpoint — never by anything in the payload (e.g. the sender's
email address is just data about the conversation, not a routing key).
This is a deliberate choice: it means onboarding a second organization
later is "generate them a token, configure their n8n workflow with it,"
nothing else changes.

If a token leaks, rotate it with `organization.regenerate_webhook_token!`
and reconfigure that org's n8n workflow with the new URL.

### Request payload

n8n extracts these fields from the Gmail message before posting — Rails
never touches the Gmail API directly for inbound mail:

| Field        | Required | Notes                                                                 |
|--------------|----------|------------------------------------------------------------------------|
| `message_id` | yes      | Gmail's `Message-Id` header (RFC 2822). The idempotency key — see below. |
| `thread_id`  | yes      | Gmail's thread id. Groups multiple emails into one `Conversation`.     |
| `from`       | yes      | Sender's email address. Stored on the `Conversation`, not used for auth. |
| `body_text`  | yes      | Plain-text body.                                                       |
| `subject`    | no       | Not currently used.                                                    |

```json
{
  "message_id": "<CAF+abc123@mail.gmail.com>",
  "thread_id": "18abz9y3f2e1c0d4",
  "from": "customer@example.com",
  "subject": "Question about my order",
  "body_text": "Hi, I'd like to return an item I bought last week..."
}
```

Any missing required field gets `422 Unprocessable Entity` with an error
body naming which ones.

### Idempotency

`message_id` is the idempotency key. Any webhook can fire more than once
for the same real event — n8n retrying a timeout, Gmail redelivering a
push notification, a slow response getting retried by the caller. Before
doing anything else, the same email arriving twice must not create two
records or send two replies.

Enforced at the database level via a unique index on
`messages.gmail_message_id`, not just an application-level existence
check — that closes the actual race where two deliveries for the same
`message_id` reach the server close enough together that a "does this
already exist?" check alone would let both through. A duplicate
(caught either by the validation or, in the race case, by the unique
index itself) still responds `200 OK` — the email doesn't need retrying,
it's already handled, and telling n8n anything else would just trigger a
retry loop.

`conversations` has a similar unique index scoped to
`(organization_id, gmail_thread_id)`, so two emails in a brand-new thread
arriving at nearly the same time can't create two conversations for the
same thread either.

### Response codes

| Status | Meaning                                                        |
|--------|-----------------------------------------------------------------|
| 200    | Accepted — whether newly processed or a known duplicate.        |
| 401    | `:webhook_token` doesn't match any organization.                 |
| 422    | Payload is missing a required field.                             |

### What happens after 200

The handler itself only verifies, dedupes, writes the inbound `Message`
(audit trail from the moment the email arrives, not after processing
finishes), and enqueues `InboundEmailProcessingJob`. That job calls
`AnswerGenerator` (same pipeline the chat UI uses) via `ReplyGenerator`
and persists a draft reply as `review_status: pending` -- nothing sends
automatically. A human approves, edits, or rejects it at `/reviews`
(`MessageReviewsController`); only approval triggers the outbound side
below.

## Outbound: Rails → n8n

The reverse direction. When a human approves a draft
(`MessageReviewsController#approve`), Rails enqueues
`SendApprovedReplyJob`, which calls `OutboundEmailService` to POST the
approved reply to the organization's n8n send-workflow. n8n does the
actual Gmail API send call, reusing the same credential it already needs
to watch the inbox -- Rails never holds Gmail OAuth.

### Endpoint

Configured per organization, not a fixed Rails route -- each org's n8n
instance/workflow has its own webhook URL, stored as
`Organization#n8n_send_webhook_url`.

### Auth

`Organization#n8n_send_webhook_secret` is sent as the `X-Webhook-Token`
header on every request. This is **n8n's** webhook auth (its built-in
header-auth feature on the receiving workflow), not Rails' -- symmetric
in shape to `:webhook_token` on the inbound side, but n8n is the one
checking it this direction, not Rails.

### Request payload

```json
{
  "to": "customer@example.com",
  "body": "Returns are accepted within 30 days of purchase with a receipt.",
  "gmail_thread_id": "18abz9y3f2e1c0d4",
  "in_reply_to": "<CAF+abc123@mail.gmail.com>"
}
```

| Field             | Notes                                                                 |
|-------------------|------------------------------------------------------------------------|
| `to`              | `Conversation#from_email` -- who to send the reply to.                 |
| `body`            | The approved (possibly human-edited) `Message#content`.                 |
| `gmail_thread_id` | Lets n8n set Gmail's own `threadId` on send, so Gmail's UI groups it correctly. |
| `in_reply_to`     | The original inbound email's `Message-Id`, for `In-Reply-To`/`References` headers -- proper RFC 2822 threading for the recipient's own mail client, not just Gmail's view. |

### Idempotency

`messages.sent_at` guards against sending the same reply twice if
`SendApprovedReplyJob` retries after a request that actually succeeded
but failed to report back before the job's timeout. Set only after
`OutboundEmailService.call` returns successfully; the job checks it
first and returns immediately if already set.

### Not yet configured

No real n8n send-workflow exists yet to point `n8n_send_webhook_url` at
-- these columns are nullable and unset for every organization today.
Building the actual n8n workflow and generating real Google Cloud OAuth
credentials for it are manual steps outside this codebase, not
something achievable via code changes here.
