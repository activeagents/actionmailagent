# frozen_string_literal: true

require "logger"
require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/inclusion"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/string/inflections"
require "active_support/notifications"
require "mail"

require "action_mail_agent/version"
require "action_mail_agent/addressing"
require "action_mail_agent/body_parser"
require "action_mail_agent/inbound_message"
require "action_mail_agent/loop_guard"

# Email as an agent transport: ActionMailbox receives, an Active Agent
# answers, ActionMailer replies on the same thread.
#
#   class SupportMailbox < ActionMailAgent::Mailbox
#     def find_conversation(inbound) = Ticket.find_by(mail_token: inbound.tags)
#     def open_conversation(inbound) = Ticket.create!(...)
#     def answer(ticket, inbound)    = SupportAgent.with(...).reply.generate_now.message.content
#     ...
#   end
#
# The gem owns the part every email/agent integration has to rebuild — and
# nothing else. A conversation is whatever the host app already calls one; the
# mailbox asks for it through hooks and never names a model.
#
#   * BodyParser     — reduce a reply chain to the sentence the person wrote
#   * Addressing     — +tag reply addresses, so a reply finds its conversation
#   * InboundMessage — one normalized view of a Mail::Message
#   * LoopGuard      — never answer a bounce, a vacation responder, or yourself
#   * Mailbox        — the exchange: parse, guard, record, answer, reply
#   * Mailer         — the headers a reply needs to land on the thread
#
module ActionMailAgent
  # These two subclass Rails classes, so they load on first use rather than
  # at require time: `require "action_mail_agent"` in a process with no
  # ActionMailbox — the unit suite, a console — loads the parsing and
  # guarding and nothing else.
  autoload :Mailbox, "action_mail_agent/mailbox"
  autoload :Mailer, "action_mail_agent/mailer"

  # Delivery modes for a generated reply.
  #
  #   :auto  — deliver it (the default)
  #   :draft — record it, deliver nothing. What a team putting an agent in
  #            front of real customers wants on day one: the replies are there
  #            to read, no customer receives one.
  #   :off   — do not generate at all; inbound mail is only recorded.
  DELIVERY_MODES = %i[auto draft off].freeze

  class << self
    # From address for replies, when the conversation does not name one. The
    # address the customer wrote to wins over this: a reply should come back
    # from the address it was sent to.
    # @return [String]
    attr_accessor :default_from

    # Domain for the +tag reply addresses that thread a conversation.
    # Defaults to the domain of the address the reply is sent from.
    # @return [String, nil]
    attr_accessor :reply_to_domain

    # @return [Symbol] one of DELIVERY_MODES
    attr_reader :delivery_mode

    def delivery_mode=(mode)
      mode = mode.to_sym
      unless DELIVERY_MODES.include?(mode)
        raise ArgumentError, "Unknown delivery mode #{mode.inspect} (expected #{DELIVERY_MODES.join(", ")})"
      end

      @delivery_mode = mode
    end

    # How many replies the agent may send to one conversation inside
    # reply_rate_window. The backstop against two autoresponders talking to
    # each other until someone notices the bill — deliberately a rate rather
    # than a count of replies "since the customer last wrote", because in a
    # loop the other end *is* writing back, and that counter would reset on
    # every bounce of the ball.
    # @return [Integer]
    attr_accessor :reply_rate_limit

    # The window reply_rate_limit is measured over. Long enough to catch a
    # loop, short enough that a customer working through a problem over a week
    # is never told to wait.
    # @return [ActiveSupport::Duration]
    attr_accessor :reply_rate_window

    # Addresses the agent itself posts from. Mail arriving from one of them is
    # never answered — that is the shape a loop takes when a support address
    # ends up subscribed to its own outbox.
    # @return [Array<String, Regexp>]
    attr_accessor :agent_addresses

    # Senders never answered: addresses, or patterns matched against the whole
    # address (`/@example\.test\z/`).
    # @return [Array<String, Regexp>]
    attr_accessor :blocked_senders

    # Marker rendered at the top of outgoing replies and treated as a quote
    # boundary on the way back in, for clients whose quoting BodyParser cannot
    # recognise.
    # @return [String, nil]
    attr_accessor :reply_delimiter

    # Called when a conversation hands off to a human:
    # `->(conversation, reason) { ... }`. The gem does not decide what a
    # handoff means for a given team — only that the conversation reached one.
    # @return [Proc, nil]
    attr_accessor :handoff_notifier

    # Where exchange outcomes are logged: whatever was assigned, else
    # Rails.logger inside a Rails app, else stdout. Resolved on every call
    # rather than memoized, so a Rails.logger swapped in after boot (or a
    # host's own assignment in an initializer) is what gets used.
    # @return [Logger]
    attr_writer :logger

    def logger
      @logger || (defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger) || fallback_logger
    end

    private

    def fallback_logger
      @fallback_logger ||= Logger.new($stdout)
    end

    public

    def configure
      yield self
    end

    # Runs the handoff notifier, if one is configured. A notifier that raises
    # must not lose the exchange: the conversation is already on record by
    # then, and the inbound email would otherwise be retried and answered
    # twice.
    def notify_handoff(conversation, reason)
      handoff_notifier&.call(conversation, reason)
    rescue StandardError => error
      logger.error("[ActionMailAgent] handoff notifier failed: #{error.class}: #{error.message}")
      nil
    end
  end

  self.default_from = "support@example.com"
  self.delivery_mode = :auto
  self.reply_rate_limit = 5
  self.reply_rate_window = 1.hour
  self.agent_addresses = []
  self.blocked_senders = []
end

require "action_mail_agent/engine" if defined?(::Rails::Engine)
