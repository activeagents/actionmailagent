# frozen_string_literal: true

# The agent that answers. On the mock provider the answer is the prompt in
# pig latin, which is all the exchange needs to prove it carried the message
# through.
class SupportAgent < ActiveAgent::Base
  generate_with :mock

  def reply
    prompt(message: params[:message])
  end
end
