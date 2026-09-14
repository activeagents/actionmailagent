# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

# Two suites, two processes.
#
# * test/unit exercises the parsing and guarding with nothing but the `mail`
#   gem and ActiveSupport — no Rails, no database. It is the suite to run
#   while working on a quoting pattern.
# * test/integration boots test/dummy, a real Rails app, and puts email
#   through ActionMailbox, the mailbox, an agent on the mock provider and
#   ActionMailer. It is the suite that proves the transport.
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/unit/**/*_test.rb"]
end

namespace :test do
  desc "Run the mailbox and mailer through the dummy Rails app"
  Rake::TestTask.new(:integration) do |t|
    t.libs << "test"
    t.libs << "lib"
    t.test_files = FileList["test/integration/**/*_test.rb"]
  end
end

task default: [ :test, "test:integration" ]
