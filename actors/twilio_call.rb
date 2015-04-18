module Notifu::Actors
  class TwilioCall < Notifu::Actor

    self.name = "twilio_call"
    self.desc = "POST requst to trigger phone-call"
    self.retry = 2

    def act
      request = {
        status: self.issue.code.to_status,
        hostname: self.issue.host,
        description: [self.issue.service.to_s, self.issue.message.to_s].join(': '),
        call_group: self.contacts.map { |contact| "#{contact.cell}"}
      }.to_json
      exec(Notifu::CONFIG[:actors][:twilio_call][:script_path] + " <<< '#{request}'")
    end

  end
end