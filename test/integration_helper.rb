# frozen_string_literal: true

# The integration suite: test/dummy is a real Rails app, and an email goes
# through ActionMailbox, SupportMailbox, an agent on the framework's mock
# provider and ActionMailer, the way it would in a host app.
ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"
require "action_mailbox/test_helper"

ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

module ActionMailAgent
  class IntegrationTest < ActiveSupport::TestCase
    include ActionMailbox::TestHelper

    setup do
      ActionMailer::Base.deliveries.clear
      ActionMailAgent.agent_addresses = [ "support@example.com" ]
    end

    private

    def receive(**options)
      receive_inbound_email_from_source(build_mail(**options).to_s)
    end

    def build_mail(from: "Dana Scully <dana@example.com>", to: "support@example.com", subject: "Export to CSV?",
                   body: "Is there a bulk CSV download?", headers: {}, **fields)
      Mail.new(
        from: from, to: to, subject: subject, body: body,
        message_id: "<#{SecureRandom.uuid}@example.com>", **fields
      ).tap do |mail|
        headers.each { |name, value| mail[name] = value }
      end
    end

    def with_config(**overrides)
      previous = overrides.keys.to_h { |key| [ key, ActionMailAgent.public_send(key) ] }
      overrides.each { |key, value| ActionMailAgent.public_send("#{key}=", value) }
      yield
    ensure
      previous.each { |key, value| ActionMailAgent.public_send("#{key}=", value) }
    end
  end
end
