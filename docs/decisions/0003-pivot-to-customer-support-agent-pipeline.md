# 3. Pivot from chat-UI RAG MVP to a Gmail-triggered support agent pipeline

## Status
Accepted

## Context
The original plan (Days 1-10) built a standalone RAG chatbot: upload
documents, ask questions in a Turbo chat UI, get cited answers. That's a
complete, shippable MVP on its own, but it's a fairly generic "RAG demo" —
one of thousands built the same way.

Separately, a larger "AI Business Automation Platform" vision exists
(multi-tenant SaaS, React frontend, billing, several AI agents, executive
dashboards) — too large to build before a job search deadline matters, and
building it linearly risks never finishing anything demoable.

## Decision
Keep the RAG core exactly as planned (upload → chunk → embed → search →
cited answer), but make the primary demo an **inbound-email customer
support agent**: Gmail → n8n (thin relay) → Rails (webhook, background
job) → RAG-augmented draft response → human approval UI → threaded email
reply → full audit history.

The large platform vision stays documented in `CLAUDE.md` as long-term
direction, not as a build target.

## Why
- The RAG core isn't wasted — it becomes the "Knowledge Base" step inside
  a more complete, more differentiated demo.
- A working email-in/email-out loop with a human-approval step is a much
  stronger portfolio piece than a chatbot: it demonstrates automation
  integration (n8n), async job design (Solid Queue), human-in-the-loop
  patterns, and audit-trail data modeling — all things "AI engineering"
  job postings actually ask about, not just "can call an LLM API."
- Scoping to one vertical slice (support agent) instead of the full
  platform (billing, multi-tenant, dashboard, multiple integrations) keeps
  the project finishable on a job-search timeline.

## Tradeoffs accepted
- No React/Next.js frontend for now — Hotwire covers the approval UI. This
  means the "Layer 1 frontend" skill from the vision doc isn't demonstrated
  by this project; that's fine, it's not what's being interviewed for.
- The "AI Agent" step is a single RAG-augmented LLM call with a
  confidence/escalate check, not a tool-calling agent (no order lookups,
  no multi-step reasoning). Upgrading to true tool-calling is explicit
  backlog, not MVP.
- n8n's role is deliberately kept thin (trigger/relay only) so that
  business logic stays in Rails, in git, and testable — this costs a
  little more Rails-side plumbing than putting logic in n8n nodes would,
  but avoids logic that can't be code-reviewed or unit tested.
