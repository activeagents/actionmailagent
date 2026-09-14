# frozen_string_literal: true

require_relative "lib/action_mail_agent/version"

Gem::Specification.new do |spec|
  spec.name = "actionmailagent"
  spec.version = ActionMailAgent::VERSION
  spec.authors = [ "Justin Bowen" ]
  spec.email = [ "jusbowen@gmail.com" ]

  spec.summary = "Email as an Active Agent transport: ActionMailbox in, ActionMailer out"
  spec.description = "Answer email with an agent. Inbound mail routes through ActionMailbox to an " \
    "Active Agent, the reply goes back out through ActionMailer on the same thread — with the " \
    "quoted-reply parsing, +tag threading and loop protection every email integration otherwise " \
    "rebuilds. Conversations stay the host app's own records."
  spec.homepage = "https://docs.activeagents.ai/actionmailagent"
  spec.license = "MIT"
  # activeagent depends on activeagents-telemetry, every release of which
  # requires Ruby >= 3.2 — so that is this gem's floor too.
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/activeagents/actionmailagent"
  spec.metadata["changelog_uri"] = "https://github.com/activeagents/actionmailagent/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/activeagents/actionmailagent/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "app/**/*",
      "lib/**/*",
      "CHANGELOG.md",
      "README.md",
      "LICENSE"
    ]
  end
  spec.require_paths = [ "lib" ]

  # The exchange runs an agent through the framework.
  spec.add_dependency "activeagent", ">= 1.4", "< 2"

  # The transport on both sides. actionmailbox brings Active Storage and Active
  # Record with it — an inbound email is a record with its raw source attached
  # — so unlike the framework this gem cannot pretend a database is optional.
  spec.add_dependency "actionmailbox", ">= 7.2", "<= 9.0"
  spec.add_dependency "actionmailer", ">= 7.2", "<= 9.0"
  spec.add_dependency "railties", ">= 7.2", "<= 9.0"
end
