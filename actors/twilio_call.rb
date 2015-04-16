module Notifu::Actors
  class TwilioCall < Notifu::Actor

    # option "name", "TwilioCall"
    # option "desc", "Twilio Call Script"

    self.name = "twilio_call"
    self.desc = "POST requst to trigger phone-call"
    self.retry = 3

    def act
      # exec...
    end

  end
end