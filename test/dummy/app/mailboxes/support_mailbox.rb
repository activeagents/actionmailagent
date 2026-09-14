# frozen_string_literal: true

# The host's half of the exchange: every hook, in the smallest form that
# still exercises the gem's contract. A real app's version of this is
# examples/support_inbox/app/mailboxes/support_mailbox.rb in the
# activeagents/activeagents repository.
class SupportMailbox < ActionMailAgent::Mailbox
  private

  def duplicate?(inbound)
    inbound.message_id.present? &&
      (Conversation.exists?(opening_message_id: inbound.message_id) || Message.exists?(message_id: inbound.message_id))
  end

  def find_conversation(inbound)
    (inbound.tags.any? && Conversation.find_by(mail_token: inbound.tags)) ||
      (inbound.reference_ids.any? && Conversation.find_by(opening_message_id: inbound.reference_ids)) ||
      (inbound.reference_ids.any? && Message.find_by(message_id: inbound.reference_ids)&.conversation) ||
      nil
  end

  def open_conversation(inbound)
    conversation = Conversation.create!(
      subject: inbound.bare_subject.presence || "(no subject)",
      customer_email: inbound.from,
      support_address: ActionMailAgent::Addressing.untagged(
        inbound.recipients.find { |address| address.start_with?("support") } || ActionMailAgent.default_from
      ),
      opening_message_id: inbound.message_id
    )
    conversation.messages.create!(role: "user", body: inbound.body, message_id: inbound.message_id)

    # A host's rule that a conversation is not the agent's, decided on the way in.
    conversation.hand_off!(reason: "escalation requested") if inbound.subject.match?(/urgent/i)
    conversation
  end

  def record_inbound(conversation, inbound)
    conversation.messages.create!(role: "user", body: inbound.body, message_id: inbound.message_id)
  end

  def answer(conversation, inbound)
    SupportAgent.with(message: inbound.body).reply.generate_now.message&.content
  end

  def record_reply(conversation, body)
    conversation.messages.create!(role: "assistant", body: body, draft: true)
  end

  def deliver(conversation, reply)
    ActionMailAgent::Mailer.with(
      to: conversation.customer_email,
      from: conversation.support_address,
      reply_to: conversation.reply_address,
      subject: conversation.subject,
      body: reply.body,
      message_id: reply.message_id,
      in_reply_to: conversation.last_inbound_message_id,
      references: conversation.reference_message_ids
    ).reply.deliver_now

    reply.update!(draft: false, delivered_at: Time.current)
  end

  def completed(conversation, reason, reply: nil)
    conversation.hand_off!(reason: "reply rate limit") if reason == :reply_limit
  end
end
