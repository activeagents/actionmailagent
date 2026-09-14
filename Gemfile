# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake", "~> 13.0"

# json 3.0 made the options to JSON.parse keyword-only; released Rails still
# passes them positionally, so an unpinned json aborts the dummy app the
# moment a json column is read back.
gem "json", "< 3"

group :test do
  gem "minitest", "~> 5.0"

  # test/integration boots a real Rails app (test/dummy) on sqlite so the
  # mailbox and mailer run against ActionMailbox and ActionMailer themselves.
  gem "sqlite3", ">= 2.0"
end
