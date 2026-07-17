# Gmail webhook contract

The seam between n8n (thin relay, watches a Gmail inbox) and Rails (all
decision logic). n8n's only job is: new email arrived → POST here. Every
other rule documented in this file lives in
`app/controllers/gmail_webhooks_controller.rb`, not in n8n's workflow
config, so it stays testable and reviewable in git.

## Endpoint

```
POST /webhooks/gmail/:webhook_token
```

## Auth

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

## Request payload

n8n extracts these fields from the Gmail message before posting — Rails
never touches the Gmail API directly for inbound mail:

| Field        | Required | Notes                                                                 |
|--------------|----------|------------------------------------------------------------------------|
| `message_id` | yes      | Gmail's `Message-Id` header (RFC 2822). The idempotency key — see below. |
| `thread_id`  | yes      | Gmail's thread id. Groups multiple emails into one `Conversation`.     |
| `from`       | yes      | Sender's email address. Stored on the `Conversation`, not used for auth. |
| `body_text`  | yes      | Plain-text body.                                                       |
| `subject`    | no       | Not currently used; reserved for the approval UI (Phase 5, later).     |

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

## Idempotency

`message_id` is the idempotency key. Any webhook can fire more than once
for the same real event — n8n retrying a timeout, Gmail redelivering a
push notification, a slow response getting retried by the caller. Before
doing anything else, the same email arriving twice must not create two
records or (once Phase 5's send step exists) send two replies.

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

## Response codes

| Status | Meaning                                                        |
|--------|-----------------------------------------------------------------|
| 200    | Accepted — whether newly processed or a known duplicate.        |
| 401    | `:webhook_token` doesn't match any organization.                 |
| 422    | Payload is missing a required field.                             |

## What happens after 200

The handler itself only verifies, dedupes, writes the inbound `Message`
(audit trail from the moment the email arrives, not after processing
finishes), and enqueues `InboundEmailProcessingJob` — currently a stub.
Generating the actual reply (`AnswerGenerator`, same pipeline the chat UI
already uses) and the human-approval step both happen later in that job
and its UI, not inline in the webhook request.
