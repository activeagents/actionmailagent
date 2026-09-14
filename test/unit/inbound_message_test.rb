require "unit_helper"

# One normalized view of an inbound email.
class ActionMailAgent::InboundMessageTest < ActionMailAgent::UnitTest
  test "the sender comes back bare and lowercase, with the display name kept aside" do
    inbound = inbound_for(build_mail(from: "Dana Scully <Dana@Example.com>"))

    assert_equal "dana@example.com", inbound.from
    assert_equal "Dana Scully", inbound.from_name
  end

  test "the bare subject drops every reply and forward prefix" do
    assert_equal "Charged twice", inbound_for(build_mail(subject: "Re: RE: Fwd: Charged twice")).bare_subject
    assert_equal "Charged twice", inbound_for(build_mail(subject: "AW: Charged twice")).bare_subject
  end

  test "message ids come back without angle brackets, In-Reply-To first" do
    inbound = inbound_for(build_mail(
      message_id: "<c@example.com>", in_reply_to: "<b@example.com>", references: "<a@example.com> <b@example.com>"
    ))

    assert_equal "c@example.com", inbound.message_id
    assert_equal [ "b@example.com", "a@example.com" ], inbound.reference_ids
  end

  test "recipients include the addresses a forwarder delivered to" do
    inbound = inbound_for(build_mail(to: "helpdesk@example.com", headers: { "Delivered-To" => "support+f3a9@example.com" }))

    assert_includes inbound.recipients, "support+f3a9@example.com"
    assert_equal [ "f3a9" ], inbound.tags
  end

  test "the body is what the person wrote, the quote is kept" do
    inbound = inbound_for(build_mail(body: "Thanks!\n\nOn Mon, Sep 1, 2025 Support wrote:\n> Done."))

    assert_equal "Thanks!", inbound.body
    assert_includes inbound.quoted_body, "Done."
  end

  test "the machine tells are read from headers, subject and sender" do
    assert inbound_for(build_mail(headers: { "Auto-Submitted" => "auto-generated" })).auto_generated?
    assert inbound_for(build_mail(subject: "Automatic reply: away")).auto_generated?
    assert inbound_for(build_mail(headers: { "List-Unsubscribe" => "<mailto:leave@example.com>" })).mailing_list?
    assert inbound_for(build_mail(from: "postmaster@example.com")).bounce?
    assert_not inbound_for(build_mail).auto_generated?
  end

  test "to_h is a log line's worth of the exchange" do
    hash = inbound_for(build_mail).to_h

    assert_equal "dana@example.com", hash[:from]
    assert_equal false, hash[:bounce]
    assert_equal %i[from from_name subject message_id references recipients attachments auto_generated mailing_list bounce], hash.keys
  end

  private

  def inbound_for(mail)
    ActionMailAgent::InboundMessage.new(mail)
  end
end
