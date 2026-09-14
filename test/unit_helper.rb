# frozen_string_literal: true

# The unit suite: parsing and guarding with nothing but the `mail` gem and
# ActiveSupport underneath. No Rails is booted, so a test here cannot
# accidentally lean on a model — the conversation the guard reads is a Struct.
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "action_mail_agent"

module ActionMailAgent
  class UnitTest < Minitest::Test
    # Assertion names the Rails suites use, so a test reads the same in both.
    alias_method :assert_not, :refute
    alias_method :assert_not_nil, :refute_nil
    alias_method :assert_not_equal, :refute_equal
    alias_method :assert_not_includes, :refute_includes

    def assert_nothing_raised
      yield
      pass
    end

    def with_config(**overrides)
      previous = overrides.keys.to_h { |key| [ key, ActionMailAgent.public_send(key) ] }
      overrides.each { |key, value| ActionMailAgent.public_send("#{key}=", value) }
      yield
    ensure
      previous.each { |key, value| ActionMailAgent.public_send("#{key}=", value) }
    end

    def build_mail(from: "dana@example.com", to: "support@example.com", subject: "Export to CSV?",
                   body: "Is there a bulk CSV download?", headers: {}, **fields)
      Mail.new(from: from, to: to, subject: subject, body: body, **fields).tap do |mail|
        headers.each { |name, value| mail[name] = value }
      end
    end
  end
end

# `test "name" do` without rails/test_help.
class Minitest::Test
  def self.test(name, &block)
    define_method("test_#{name.gsub(/\W+/, "_")}", &block)
  end
end
