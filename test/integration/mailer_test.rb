require "integration_helper"

# The headers a reply needs to land on the customer's thread.
class ActionMailAgent::MailerTest < ActionMailAgent::IntegrationTest
  test "a reply carries every threading header" do
    email = ActionMailAgent::Mailer.with(
      to: "dana@example.com", from: "support@example.com", reply_to: "support+f3a9@example.com",
      subject: "Charged twice", body: "Refunded.",
      message_id: "reply-1@example.com", in_reply_to: "<inbound-2@example.com>",
      references: [ "inbound-1@example.com", "<inbound-2@example.com>", "reply-1@example.com" ]
    ).reply

    assert_equal "reply-1@example.com", email.message_id
    assert_equal "inbound-2@example.com", email.in_reply_to
    assert_equal [ "inbound-1@example.com", "inbound-2@example.com" ], email.references, "a message does not reference itself"
    assert_equal "auto-replied", email["Auto-Submitted"].to_s
    assert_equal [ "support+f3a9@example.com" ], email.reply_to
    assert_equal "Re: Charged twice", email.subject
  end

  test "a subject that is already a reply keeps one prefix" do
    email = ActionMailAgent::Mailer.with(to: "dana@example.com", subject: "RE: Charged twice", body: "Refunded.").reply

    assert_equal "RE: Charged twice", email.subject
    assert_equal [ ActionMailAgent.default_from ], email.from
  end

  test "the delimiter and signature are rendered into both parts" do
    with_config(reply_delimiter: "##- reply above -##") do
      email = ActionMailAgent::Mailer.with(to: "dana@example.com", subject: "Hi", body: "Refunded.", signature: "The Support Team").reply

      assert_includes email.text_part.decoded, "##- reply above -##"
      assert_includes email.text_part.decoded, "The Support Team"
      assert_includes email.html_part.decoded, "<p>Refunded.</p>"
    end
  end
end
