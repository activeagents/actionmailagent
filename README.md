# Action Mail Agent

Email as an Active Agent transport: ActionMailbox in, ActionMailer out.

```
inbound email ─▶ ActionMailbox ─▶ your Mailbox ─▶ your Agent ─▶ ActionMailAgent::Mailer ─▶ reply
                                       │              │
                                 your records    solid_agent + telemetry (optional)
```

A customer emails `support@`; an [Active Agent](https://github.com/activeagents/activeagent)
answers; the answer goes back on the customer's thread. This gem owns the part
every email/agent integration has to rebuild — and nothing else. A conversation
is whatever your app already calls one.

Sibling to [`activeagent`](https://github.com/activeagents/activeagent),
[`solid_agent`](https://github.com/activeagents/solid_agent) and
[`actionagent`](https://github.com/activeagents/activeagent/tree/main/actionagent),
named the way `actionmailer` and `actionmailbox` are.

## What it handles

| | |
|---|---|
| `BodyParser` | Reduces a reply chain to what the person wrote *this time* — Gmail/Outlook/Apple quoting, wrapped attributions, forwarded-message separators, signatures, HTML-only mail |
| `Addressing` | The `support+<token>@` reply addresses conversations thread on — lowercase, because addresses do not survive a round trip through the mail system with their case intact |
| `InboundMessage` | One normalized view of a `Mail::Message`: sender, bare subject, thread ids, +tags, and the header tells that say a machine sent it |
| `LoopGuard` | Refuses bounces, vacation responders, mailing lists, your own addresses, blocked senders, and a conversation that has burst past its reply rate |
| `Mailbox` | The exchange itself — parse, guard, record, answer, reply — with hooks your app fills in |
| `Mailer` | `Message-ID`, `In-Reply-To`, `References`, `Reply-To`, `Auto-Submitted`: the headers a reply needs to land on the thread |

Threading works two ways because one is not enough: the `+tag` survives
clients that rewrite headers, and the `References`/`In-Reply-To` chain
catches replies sent to the plain address.

## Install

```ruby
# Gemfile
gem "activeagent"
gem "actionmailagent"
```

```sh
bin/rails action_mailbox:install   # if you haven't already
bin/rails db:migrate
```

The gem ships no tables. Your conversation and message records are your own —
they need a token column for the reply address and a place to keep message
ids, and that is all.

## Use

```ruby
# app/mailboxes/application_mailbox.rb
class ApplicationMailbox < ActionMailbox::Base
  # The support address, and the +tagged reply addresses conversations thread on.
  routing(/\Asupport(\+[^@]+)?@/i => :support)
end

# app/mailboxes/support_mailbox.rb
class SupportMailbox < ActionMailAgent::Mailbox
  private

  # The +tag first, because it survives clients that rewrite headers; the
  # References chain second, for a customer who replied to the plain address.
  def find_conversation(inbound)
    Ticket.find_by(mail_token: inbound.tags) ||
      Reply.find_by(message_id: inbound.reference_ids)&.ticket
  end

  def open_conversation(inbound)
    Ticket.create!(subject: inbound.bare_subject, body: inbound.body,
                   customer_email: inbound.from, mail_message_id: inbound.message_id)
  end

  def record_inbound(ticket, inbound)
    ticket.replies.create!(inbound: true, body: inbound.body, message_id: inbound.message_id)
  end

  def answer(ticket, inbound)
    SupportAgent.with(ticket: ticket, message: inbound.body).reply.generate_now.message&.content
  end

  def record_reply(ticket, body)
    ticket.replies.create!(body: body, ai_generated: true)
  end

  def deliver(ticket, reply)
    ActionMailAgent::Mailer.with(
      to: ticket.customer_email,
      from: "support@example.com",
      reply_to: ActionMailAgent::Addressing.tagged("support@example.com", ticket.mail_token),
      subject: ticket.subject,
      body: reply.body,
      message_id: reply.message_id,
      in_reply_to: ticket.last_inbound_message_id,
      references: ticket.reference_message_ids
    ).reply.deliver_now
  end
end
```

The agent is any Active Agent — `inbound.body` is the customer's new text
with the quoted thread already removed, so a
[solid_agent](https://github.com/activeagents/solid_agent) context can carry
the history instead of the email quoting it.

Two optional methods on your conversation let the guard read it:
`handed_off?` (a human took over; the agent stays out) and
`agent_replies_within(window)` (recent answers, for the rate limit).

## Configure

```ruby
# config/initializers/action_mail_agent.rb
ActionMailAgent.configure do |config|
  config.default_from = "support@example.com"

  # :auto sends replies, :draft records them and sends nothing, :off stops
  # generating. Rolling an agent out in front of real customers starts at :draft.
  config.delivery_mode = :auto

  # Mail from these is never answered — that is what a loop looks like from the inside.
  config.agent_addresses = [ "support@example.com" ]
  config.blocked_senders = [ /@spam\.example\z/ ]

  # More than five answers on one conversation in an hour is not a conversation.
  config.reply_rate_limit = 5
  config.reply_rate_window = 1.hour

  # Rendered at the top of every reply; recognised as a quote boundary coming back.
  config.reply_delimiter = "##- Please type your reply above this line -##"

  # What a handoff means for your team.
  config.handoff_notifier = ->(conversation, reason) { Pager.page(:support, conversation, reason) }
end
```

Every processed email instruments `exchange.action_mail_agent` with the
outcome (`reason: nil` when answered; a `LoopGuard` reason, `:no_answer`,
`:draft_mode`, `:handed_off` or `:delivery_off` when not).

## Reference implementation

[`examples/support_inbox`](examples/support_inbox) is the app this was
extracted from, and it runs against this checkout: tickets that arrive by
email, triaged on the way in, answered by an agent with a
[solid_agent](https://github.com/activeagents/solid_agent) conversation, and
visible on the [actionagent](https://github.com/activeagents/activeagent/tree/main/actionagent)
dashboard as traces. Its `SupportMailbox` is ~130 lines of ticket-specific
code on top of this gem's contract, and its suite runs in CI against the gem
at HEAD.

```sh
cd examples/support_inbox
bundle install
bin/rails db:prepare db:seed
bin/rails server
```

Then paste an email into
`http://localhost:3000/rails/conductor/action_mailbox/inbound_emails/new` and
watch it become a triaged, answered ticket at `http://localhost:3000`, with
the traces at `/activeagents`.

## Development

```sh
bundle install
bundle exec rake                   # both suites
bundle exec rake test              # unit: parsing and guarding, no Rails
bundle exec rake test:integration  # the dummy Rails app: ActionMailbox → agent → ActionMailer
```

## License

MIT — see [LICENSE](LICENSE).
