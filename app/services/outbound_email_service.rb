require "net/http"
require "json"

# POSTs an approved reply to the organization's n8n workflow for actual
# delivery -- symmetric to GmailWebhooksController's inbound direction,
# just reversed: Rails calls out to n8n instead of n8n calling in. n8n
# owns the real Gmail API call (send), reusing the same credential it
# already needs to watch the inbox; Rails never touches Gmail OAuth.
# See docs/webhook-contract.md's "Outbound" section for the payload
# shape and auth.
class OutboundEmailService
  class RequestFailed < StandardError; end

  def self.call(message)
    conversation = message.conversation
    organization = conversation.organization

    uri = URI.parse(organization.n8n_send_webhook_url)
    payload = {
      to: conversation.from_email,
      body: message.content,
      gmail_thread_id: conversation.gmail_thread_id,
      in_reply_to: message.question&.gmail_message_id
    }

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    # n8n's own webhook auth, not Rails' -- the shared secret n8n's
    # workflow is configured to expect, symmetric to :webhook_token on
    # the inbound side but this direction n8n owns the check.
    request["X-Webhook-Token"] = organization.n8n_send_webhook_secret
    request.body = payload.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }

    raise RequestFailed, "n8n send webhook returned #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    response
  end
end
