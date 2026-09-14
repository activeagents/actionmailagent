# frozen_string_literal: true

# A host app's conversation record, written to satisfy the mailbox hooks and
# the two duck-typed methods LoopGuard reads (handed_off?,
# agent_replies_within). Everything here is the host's choice; the gem never
# names this class.
class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy

  before_validation { self.mail_token ||= ActionMailAgent::Addressing.generate_token }

  def reply_address
    ActionMailAgent::Addressing.tagged(support_address, mail_token)
  end

  def last_inbound_message_id
    messages.where(role: "user").order(:created_at).last&.message_id.presence || opening_message_id
  end

  def reference_message_ids
    [ opening_message_id, *messages.order(:created_at).pluck(:message_id) ].compact_blank.uniq
  end

  def handed_off?
    handed_off_at.present?
  end

  def hand_off!(reason:)
    update!(handed_off_at: Time.current, handoff_reason: reason)
    ActionMailAgent.notify_handoff(self, reason)
  end

  def agent_replies_within(window)
    messages.where(role: "assistant", created_at: window.ago..).count
  end
end
