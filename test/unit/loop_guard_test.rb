require "unit_helper"

# Which inbound mail an agent is allowed to answer. Everything here is a way
# an agent ends up in a conversation with another machine, which is the
# expensive failure mode of putting one on an email address.
class ActionMailAgent::LoopGuardTest < ActionMailAgent::UnitTest
  test "an ordinary email is answered" do
    assert_nil reason_for(build_mail)
  end

  test "a vacation responder is not" do
    assert_equal :auto_generated, reason_for(build_mail(headers: { "Auto-Submitted" => "auto-replied" }))
    assert_equal :auto_generated, reason_for(build_mail(headers: { "Precedence" => "bulk" }))
    assert_equal :auto_generated, reason_for(build_mail(headers: { "X-Auto-Response-Suppress" => "OOF" }))
    assert_equal :auto_generated, reason_for(build_mail(subject: "Out of office: Dana Scully"))
  end

  test "Auto-Submitted: no is a human saying so" do
    assert_nil reason_for(build_mail(headers: { "Auto-Submitted" => "no" }))
  end

  test "a bounce is not answered" do
    assert_equal :bounce, reason_for(build_mail(from: "MAILER-DAEMON@example.com"))
    assert_equal :bounce, reason_for(build_mail(headers: { "X-Failed-Recipients" => "dana@example.com" }))
  end

  test "a mailing list is not answered" do
    assert_equal :mailing_list, reason_for(build_mail(headers: { "List-Id" => "<rails-talk.example.com>" }))
  end

  test "our own address is never answered, tagged or not" do
    with_config(agent_addresses: [ "support@example.com" ]) do
      assert_equal :agent_address, reason_for(build_mail(from: "support@example.com"))
      assert_equal :agent_address, reason_for(build_mail(from: "Support <SUPPORT+f3a9c1d8@example.com>"))
    end
  end

  test "a blocked sender is not answered" do
    with_config(blocked_senders: [ /@spam\.example\z/ ]) do
      assert_equal :blocked_sender, reason_for(build_mail(from: "bot@spam.example"))
    end
  end

  test "an empty message is not answered" do
    assert_equal :no_content, reason_for(build_mail(body: "   "))
  end

  test "a conversation a human took over is not answered" do
    assert_equal :handed_off, reason_for(build_mail, conversation: conversation(handed_off: true))
  end

  test "a burst of replies on one conversation stops the agent" do
    burst = conversation(recent_replies: ActionMailAgent.reply_rate_limit)

    assert_equal :reply_limit, reason_for(build_mail, conversation: burst)
  end

  test "one reply short of the limit is still a conversation" do
    calm = conversation(recent_replies: ActionMailAgent.reply_rate_limit - 1)

    assert_nil reason_for(build_mail, conversation: calm)
  end

  test "a conversation that answers neither question is left alone" do
    assert_nil reason_for(build_mail, conversation: Object.new)
  end

  private

  def reason_for(mail, conversation: nil)
    ActionMailAgent::LoopGuard.new(ActionMailAgent::InboundMessage.new(mail), conversation: conversation).reason
  end

  # The two methods the guard reads off a conversation, and nothing else.
  Conversation = Struct.new(:handed_off, :recent_replies, keyword_init: true) do
    def handed_off? = !!handed_off
    def agent_replies_within(_window) = recent_replies.to_i
  end

  def conversation(**attributes)
    Conversation.new(**attributes)
  end
end
