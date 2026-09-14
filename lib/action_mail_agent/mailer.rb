# frozen_string_literal: true

require "action_mailer"

module ActionMailAgent
  # Sends an agent's answer back out on the customer's thread.
  #
  #   ActionMailAgent::Mailer.with(
  #     to: "dana@example.com",
  #     from: "support@example.com",
  #     reply_to: "support+f3a9c1d8@example.com",
  #     subject: "Charged twice this month",
  #     body: answer_text,
  #     message_id: reply.message_id,             # assigned before delivery
  #     in_reply_to: inbound.message_id,
  #     references: ticket.reference_message_ids
  #   ).reply.deliver_now
  #
  # The headers are the whole job. Get them wrong and every reply starts a new
  # conversation in the customer's client, their answer comes back unthreaded,
  # and a second autoresponder on their side will happily talk to this one
  # forever.
  #
  # Subclass it to brand the templates: a host's `SupportMailer <
  # ActionMailAgent::Mailer` with its own `reply.text.erb` and layout wins
  # over the ones shipped in the engine.
  class Mailer < ActionMailer::Base
    # Subjects that already answer something keep their prefix; one "Re:" is
    # correct, and "Re: Re: Re:" is what happens when nobody checks.
    REPLY_PREFIX = /\A\s*(re|aw|sv|antw)\s*:\s*/i

    def reply
      @body = params.fetch(:body)
      @delimiter = params.fetch(:delimiter, ActionMailAgent.reply_delimiter)
      @signature = params[:signature]

      # Ours to set, and set before delivery: a host that assigns the id when
      # it records the reply can match the customer's answer — which will
      # quote it in In-Reply-To — back to the conversation, even when the
      # reply is generated now and delivered later.
      headers["Message-ID"] = bracket(params[:message_id]) if params[:message_id].present?

      # What this answers, and the thread it belongs to. The new id is dropped
      # from References: a message does not reference itself.
      headers["In-Reply-To"] = bracket(params[:in_reply_to]) if params[:in_reply_to].present?

      references = Array(params[:references]).map { |id| unbracket(id) }.compact_blank.uniq - [ unbracket(params[:message_id]) ]
      headers["References"] = references.map { |id| bracket(id) }.join(" ") if references.any?

      # RFC 3834. This is a generated reply, and saying so is what keeps the
      # vacation responder on the other side from answering it — the same
      # courtesy LoopGuard expects from everyone else.
      headers["Auto-Submitted"] = "auto-replied"

      mail(
        to: params.fetch(:to),
        from: params.fetch(:from) { ActionMailAgent.default_from },
        reply_to: params[:reply_to],
        subject: reply_subject(params.fetch(:subject)),
        # ActionMailer looks templates up under the mailer's own name alone —
        # not, as a controller would, up the class chain — so a subclass
        # without reply.text.erb of its own would raise MissingTemplate
        # instead of rendering the templates shipped here. Searching every
        # prefix restores the controller behaviour: a host's own templates
        # win, and the gem's are the fallback.
        template_path: _prefixes
      )
    end

    private

    def reply_subject(subject)
      subject = subject.to_s.strip
      subject.match?(REPLY_PREFIX) ? subject : "Re: #{subject}"
    end

    def bracket(message_id)
      id = unbracket(message_id)
      id.present? ? "<#{id}>" : nil
    end

    def unbracket(message_id)
      message_id.to_s.strip.delete("<>").presence
    end
  end
end
