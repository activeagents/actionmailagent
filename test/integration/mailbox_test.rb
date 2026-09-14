require "integration_helper"

# The exchange end to end: ActionMailbox in, the agent in the middle,
# ActionMailer out, threaded onto the same conversation.
class ActionMailAgent::MailboxTest < ActionMailAgent::IntegrationTest
  test "a first email opens a conversation and the agent answers it on the thread" do
    receive(subject: "Charged twice this month", body: "Can you refund the duplicate?")

    conversation = Conversation.sole
    assert_equal "dana@example.com", conversation.customer_email
    assert_equal "Charged twice this month", conversation.subject
    assert_equal "Can you refund the duplicate?", conversation.messages.inbound.sole.body

    answer = conversation.messages.outbound.sole
    assert answer.delivered_at.present?
    assert_not answer.draft?

    email = ActionMailer::Base.deliveries.sole
    assert_equal [ "dana@example.com" ], email.to
    assert_equal [ "support@example.com" ], email.from
    assert_equal [ conversation.reply_address ], email.reply_to
    assert_equal "Re: Charged twice this month", email.subject
    assert_equal answer.message_id, email.message_id
    assert_equal conversation.opening_message_id, email.in_reply_to
    assert_equal "auto-replied", email["Auto-Submitted"].to_s
  end

  test "a reply to the tagged address continues the conversation, threaded on the whole chain" do
    receive
    conversation = Conversation.sole
    first_answer = conversation.messages.outbound.sole

    receive(to: conversation.reply_address, subject: "Re: Export to CSV?", body: "Does that include archived records?")

    assert_equal 1, Conversation.count, "a reply must not open a second conversation"
    assert_equal 2, conversation.messages.inbound.count
    assert_equal 2, conversation.messages.outbound.count

    second_answer = ActionMailer::Base.deliveries.last
    follow_up = conversation.messages.inbound.order(:created_at).last
    assert_equal follow_up.message_id, second_answer.in_reply_to
    assert_includes Array(second_answer.references), conversation.opening_message_id
    assert_includes Array(second_answer.references), first_answer.message_id
    assert_not_includes Array(second_answer.references), second_answer.message_id
  end

  test "a reply threads by References when the tag is gone" do
    receive
    conversation = Conversation.sole
    answer = conversation.messages.outbound.sole

    receive(to: "support@example.com", subject: "Re: Export to CSV?", body: "Still nothing.",
            references: "<#{conversation.opening_message_id}> <#{answer.message_id}>")

    assert_equal 1, Conversation.count
    assert_equal 2, conversation.messages.inbound.count
  end

  test "the quoted thread is stripped before the agent sees it" do
    receive
    conversation = Conversation.sole

    receive(to: conversation.reply_address, subject: "Re: Export to CSV?", body: <<~BODY)
      Perfect, thank you.

      On Mon, Sep 1, 2025 at 9:03 AM Support <support@example.com> wrote:
      > You can export everything from Settings.
    BODY

    assert_equal "Perfect, thank you.", conversation.messages.inbound.last.body
  end

  test "an auto-reply is recorded but never answered" do
    receive
    conversation = Conversation.sole
    ActionMailer::Base.deliveries.clear

    receive(to: conversation.reply_address, subject: "Out of office", body: "Away until Monday.",
            headers: { "Auto-Submitted" => "auto-replied" })

    assert_equal 2, conversation.messages.inbound.count, "the message is still on record"
    assert_equal 1, conversation.messages.outbound.count, "but the agent does not answer a machine"
    assert_empty ActionMailer::Base.deliveries
  end

  test "a bounce never opens a conversation" do
    receive(from: "MAILER-DAEMON@example.com", subject: "Undeliverable: Export", body: "Could not be delivered.")

    assert_equal 0, Conversation.count
    assert_empty ActionMailer::Base.deliveries
  end

  test "a resend after the first copy was incinerated is still answered once" do
    source = build_mail.to_s
    receive_inbound_email_from_source(source).destroy!

    receive_inbound_email_from_source(source)

    assert_equal 1, Conversation.count
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "a conversation handed off on the way in is recorded and not answered" do
    receive(subject: "URGENT: production down", body: "Everything is 500ing.")

    conversation = Conversation.sole
    assert conversation.handed_off?
    assert_empty conversation.messages.outbound
    assert_empty ActionMailer::Base.deliveries
  end

  test "a burst of replies stops the agent and hands the conversation off" do
    receive
    conversation = Conversation.sole
    (ActionMailAgent.reply_rate_limit - 1).times { |i| conversation.messages.create!(role: "assistant", body: "Answer #{i}") }
    ActionMailer::Base.deliveries.clear

    receive(to: conversation.reply_address, subject: "Re: Export to CSV?", body: "Please advise.")

    assert_empty ActionMailer::Base.deliveries
    assert conversation.reload.handed_off?
    assert_equal "reply rate limit", conversation.handoff_reason
  end

  test "draft mode records the answer and sends nothing" do
    with_config(delivery_mode: :draft) { receive }

    answer = Conversation.sole.messages.outbound.sole
    assert answer.draft?
    assert_empty ActionMailer::Base.deliveries
  end

  test "off records the email and generates nothing" do
    with_config(delivery_mode: :off) { receive }

    assert_equal 1, Conversation.sole.messages.inbound.count
    assert_empty Conversation.sole.messages.outbound
  end

  test "every processed email is instrumented with its outcome" do
    outcomes = []
    subscriber = ActiveSupport::Notifications.subscribe(ActionMailAgent::Mailbox::NOTIFICATION) do |*, payload|
      outcomes << payload.slice(:reason, :replied)
    end

    receive
    receive(from: "MAILER-DAEMON@example.com", subject: "Undeliverable", body: "Not delivered.")

    assert_equal [ { reason: nil, replied: true }, { reason: :bounce, replied: false } ], outcomes
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
