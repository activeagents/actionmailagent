# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :conversation

  scope :inbound, -> { where(role: "user") }
  scope :outbound, -> { where(role: "assistant") }

  # An outbound message gets its Message-Id before it is sent, so the answer
  # to it can be threaded back even if delivery happens later.
  before_create { self.message_id ||= "#{SecureRandom.uuid}@example.com" if role == "assistant" }
end
