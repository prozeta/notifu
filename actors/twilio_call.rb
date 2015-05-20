module Notifu
  module Actors
    class TwilioCall < Notifu::Actor

      require 'excon'
      require 'erb'

      self.name = "twilio_call"
      self.desc = "POST requst to trigger phone-call"
      self.retry = 2

      def act
        contacts = self.contacts.map { |contact| contact.cell }
        req_string = Notifu::CONFIG[:actors][:twilio_call][:api] +
                      "?token="       + Notifu::CONFIG[:actors][:twilio_call][:token] +
                      "&status="      + self.issue.code.to_state +
                      "&hostname="    + self.issue.host +
                      "&service="     + self.issue.service +
                      "&description=" + ERB::Util.url_encode(self.issue.message.to_s) +
                      "&call_group="  + ERB::Util.url_encode(contacts.to_json) +
                      "&init=1"
        Excon.get req_string if self.issue.code.to_i == 2
      end

    end
  end
end
