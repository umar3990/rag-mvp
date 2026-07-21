# Setting up n8n + Gmail (manual, one-time)

Everything in `app/controllers/gmail_webhooks_controller.rb`,
`app/services/outbound_email_service.rb`, and `docs/webhook-contract.md`
is already built and tested. This doc is the other half: the manual
setup outside this codebase that makes those endpoints actually receive
and send real email. Nothing here is code — it's Google Cloud Console
clicks, n8n's own UI, and a handful of Rails console commands to wire
the two together.

Per `CLAUDE.md`'s stack decision, n8n runs **self-hosted via Docker**,
not n8n's paid cloud product — so there's no third-party account to
sign up for. "Logging into n8n" just means creating a local admin login
inside your own container the first time you open it, the same as any
self-hosted app.

## Overview of what you're building

Two n8n workflows, both talking to the same Rails app:

1. **Inbound**: Gmail Trigger (watches your inbox) → HTTP Request →
   `POST /webhooks/gmail/:webhook_token` (already built, see
   `docs/webhook-contract.md`).
2. **Outbound**: Webhook (Rails calls this when a human approves a
   reply) → Gmail node (sends the reply) → respond.

Both need the same underlying thing: an OAuth2 credential in n8n that's
allowed to read and send mail on your Gmail account. You set that up
once and both workflows reuse it.

---

## Step 1 — Run n8n locally via Docker

Already in `docker-compose.yml` as the `n8n` service:

```
docker compose up -d n8n
```

Open `http://localhost:5678` — first visit prompts you to create a
local owner account (email + password, stored only in your own
`n8n_data` volume). That's the entire "n8n account" step.

## Step 2 — Google Cloud: OAuth client for Gmail

n8n needs its own OAuth2 client to act on your Gmail account.

1. Go to [console.cloud.google.com](https://console.cloud.google.com) →
   create a new project (any name, e.g. "rag-mvp-gmail").
2. **APIs & Services → Library** → search "Gmail API" → Enable.
3. **APIs & Services → OAuth consent screen**:
   - User type: **External** (fine for personal/testing use — you'll
     add your own Gmail as a test user, no Google review needed since
     you're not publishing this).
   - Fill in the required app name/support email fields (anything
     reasonable).
   - Scopes: add `.../auth/gmail.readonly` and `.../auth/gmail.send` (or
     the broader `.../auth/gmail.modify` if you want a single scope
     covering both).
   - Test users: add the Gmail address you're connecting.
4. **APIs & Services → Credentials → Create Credentials → OAuth client
   ID**:
   - Application type: **Web application**.
   - You'll need the exact redirect URI n8n's Gmail credential screen
     shows you (step 3 below shows it before you need to paste it back
     here) — Google requires the redirect URI to match exactly, so do
     step 3 first, copy the URI it displays, then come back and add it
     under "Authorized redirect URIs" here.
5. Save. You'll get a **Client ID** and **Client Secret** — copy both.

## Step 3 — Connect the Gmail credential in n8n

1. In n8n: **Credentials → New → Gmail OAuth2 API**.
2. n8n shows you an **OAuth Redirect URL** on this screen — this is the
   exact value to paste into Google Cloud's "Authorized redirect URIs"
   (step 2.4 above) if you haven't already.
3. Paste in the Client ID / Client Secret from step 2.5.
4. Click **Connect my account** — this opens a real Google OAuth consent
   flow, sign in with the Gmail account you added as a test user, grant
   access.
5. n8n confirms the credential is connected. Both workflows below reuse
   this one credential.

## Step 4 — Get your organization's inbound webhook URL

Rails already generated a `webhook_token` for your organization
(`Organization#webhook_token`, via `has_secure_token` — done automatically
when the organization was created, nothing to run). Get it:

```
bin/rails runner 'puts Organization.first.webhook_token'
```

Your inbound URL is:

```
http://<wherever-rails-is-reachable>/webhooks/gmail/<that token>
```

In local dev, n8n (in Docker) reaching Rails (on the host, per
`notes.md`'s Ollama setup) needs `host.docker.internal` instead of
`localhost`:

```
http://host.docker.internal:3000/webhooks/gmail/<token>
```

(For a real deployed instance later, this is just your production
domain instead.)

## Step 5 — Build the inbound workflow

In n8n, new workflow:

1. **Gmail Trigger** node — credential: the one from Step 3. Trigger on
   new messages (poll interval is fine for a personal Gmail account,
   e.g. every minute).
2. **HTTP Request** node, connected after it:
   - Method: `POST`
   - URL: the inbound URL from Step 4
   - Body (JSON), mapped from the Gmail Trigger node's output fields —
     exact field names per `docs/webhook-contract.md`:
     ```json
     {
       "message_id": "={{ $json.headers['message-id'] }}",
       "thread_id": "={{ $json.threadId }}",
       "from": "={{ $json.from.value[0].address }}",
       "subject": "={{ $json.subject }}",
       "body_text": "={{ $json.text }}"
     }
     ```
     (Exact expression paths depend on n8n's Gmail Trigger output shape
     at the version you're on — use n8n's expression editor / the node's
     output preview to confirm these field paths against a real test
     email before trusting them.)
3. Activate the workflow.

Send yourself a test email and confirm (via `bin/rails console`) that a
`Conversation`/`Message` got created:

```ruby
Organization.first.conversations.order(created_at: :desc).first
```

## Step 6 — Build the outbound workflow

New workflow:

1. **Webhook** node — this is n8n's *trigger*, listening for Rails to
   call it:
   - Method: `POST`
   - Path: anything, e.g. `send-reply`
   - Authentication: **Header Auth** — set a header name (e.g.
     `X-Webhook-Token`) and a secret value you make up. This is the
     value that goes into `n8n_send_webhook_secret` in Step 7.
   - Note the **Production URL** n8n shows once the workflow is active
     — that's your `n8n_send_webhook_url`.
2. **Gmail** node, connected after it — action: **Reply to a message**
   (or **Send**, depending on your n8n version's Gmail node options):
   - To: `={{ $json.body.to }}`
   - Message: `={{ $json.body.body }}`
   - Thread ID: `={{ $json.body.gmail_thread_id }}`
   - If the node exposes them, also set `In-Reply-To` /`References`
     headers from `={{ $json.body.in_reply_to }}` — this is what makes
     the reply thread correctly in the *recipient's* mail client, not
     just Gmail's own view (see `docs/webhook-contract.md`'s outbound
     section for why both matter).
3. **Respond to Webhook** node at the end (200 OK) so Rails' request
   completes cleanly.
4. Activate the workflow.

## Step 7 — Tell Rails where to send

```ruby
org = Organization.first
org.update!(
  n8n_send_webhook_url: "http://host.docker.internal:5678/webhook/send-reply",
  n8n_send_webhook_secret: "the secret you set in the Webhook node's Header Auth"
)
```

## Step 8 — Test end to end

1. Send a real test email to the connected Gmail address.
2. Confirm it shows up at `/reviews` in the Rails app.
3. Approve it (editing the content if you want).
4. Confirm the reply actually lands in your test email's inbox, threaded
   under the original message.

If step 4 fails, check `bin/jobs`/Solid Queue logs for
`SendApprovedReplyJob` — `OutboundEmailService::RequestFailed` means n8n
responded with a non-2xx, and the error message includes n8n's response
body.
