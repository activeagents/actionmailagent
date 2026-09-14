# frozen_string_literal: true

module ActionMailAgent
  # The engine exists for one thing: the reply templates under app/views, so
  # ActionMailAgent::Mailer renders without the host copying anything. It
  # mounts no routes and owns no tables.
  class Engine < ::Rails::Engine
    isolate_namespace ActionMailAgent

    engine_name "action_mail_agent"

    config.action_mail_agent = ActiveSupport::OrderedOptions.new

    # `config.action_mail_agent.delivery_mode = :draft` in an environment file
    # is how the rest of Rails is configured, and it lands here. An
    # `ActionMailAgent.configure` block in an initializer works the same and
    # reads better; both are fine, and an app that sets neither gets the
    # defaults.
    initializer "action_mail_agent.config" do |app|
      app.config.action_mail_agent.each do |name, value|
        setter = "#{name}="
        ActionMailAgent.public_send(setter, value) if ActionMailAgent.respond_to?(setter)
      end
    end
  end
end
