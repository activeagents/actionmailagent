# frozen_string_literal: true

require "rails"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_view/railtie"

require "active_agent"
require "action_mail_agent"

module Dummy
  # The smallest Rails app that can receive an email: Active Record and Active
  # Storage for ActionMailbox's inbound email records, ActionMailer for the
  # reply, and the framework for the agent that answers. The conversation
  # models are in app/models, the way a host app's would be.
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(File::NULL)
    config.log_level = :warn
    config.active_support.deprecation = :stderr

    config.active_record.maintain_test_schema = false
    config.active_storage.service = :test

    config.action_mailer.delivery_method = :test
    config.action_mailer.default_url_options = { host: "example.com" }
    config.action_mailer.perform_deliveries = true

    config.action_mailbox.ingress = nil

    # Routing in the tests is synchronous (ActionMailbox::TestHelper), so no
    # job needs performing — and ActionMailbox schedules incineration 30 days
    # out after every email, which :inline refuses to do.
    config.active_job.queue_adapter = :test
  end
end
