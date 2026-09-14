# frozen_string_literal: true

class ApplicationMailbox < ActionMailbox::Base
  routing(/\Asupport(\+[^@]+)?@/i => :support)
end
