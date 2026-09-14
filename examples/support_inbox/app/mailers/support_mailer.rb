# The agent's answers go out through the gem's mailer, which owns the headers
# that thread a reply onto the customer's conversation (Message-ID,
# In-Reply-To, References, Reply-To, Auto-Submitted). What is left to this
# app is the branding: the layout, and who signs.
class SupportMailer < ActionMailAgent::Mailer
  layout "mailer"
end
