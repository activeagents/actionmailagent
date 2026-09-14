require "unit_helper"

# The +tag half of threading, and the normalizing that makes two spellings of
# one address compare equal.
class ActionMailAgent::AddressingTest < ActionMailAgent::UnitTest
  Addressing = ActionMailAgent::Addressing

  test "tagging inserts the token before the @" do
    assert_equal "support+f3a9c1d8@example.com", Addressing.tagged("support@example.com", "f3a9c1d8")
  end

  test "tagging an already tagged address replaces the tag" do
    assert_equal "support+new@example.com", Addressing.tagged("support+old@example.com", "new")
  end

  test "tagging can move the reply to another domain" do
    assert_equal "support+t@replies.example.com", Addressing.tagged("support@example.com", "t", domain: "replies.example.com")
  end

  test "tags come off every recipient that carries one" do
    assert_equal [ "f3a9", "b2c1" ], Addressing.tags([ "support+f3a9@example.com", "ops@example.com", "Sales <sales+b2c1@example.com>" ])
  end

  test "untagging strips the tag and the display name" do
    assert_equal "support@example.com", Addressing.untagged("Support <Support+f3a9@Example.com>")
  end

  test "matching compares the plain and the tagged form against strings and patterns" do
    assert Addressing.match?("support+f3a9@example.com", [ "support@example.com" ])
    assert Addressing.match?("bot@spam.example", [ /@spam\.example\z/ ])
    assert_not Addressing.match?("dana@example.com", [ "support@example.com", /@spam\.example\z/ ])
    assert_not Addressing.match?("", [ "" ])
  end

  test "a token is lowercase and long enough to be a bearer credential" do
    token = Addressing.generate_token

    assert_equal token, token.downcase
    assert_operator token.length, :>=, 24
    assert_not_equal token, Addressing.generate_token
  end
end
