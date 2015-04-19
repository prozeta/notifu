module Notifu
  module Actors
    class Smtp < Notifu::Actor

      require 'ostruct'
      require 'mail'

      self.name = "smtp"
      self.desc = "SMTP notifier"
      self.retry = 2

      def act
        data = OpenStruct.new({
          notifu_id: self.issue.notifu_id,
          host: self.issue.host,
          message: self.issue.message,
          service: self.issue.service,
          status: self.issue.code.to_state,
          first_event: Time.at(self.issue.time_created.to_i),
          duration: (Time.now.to_i - self.issue.time_created.to_i).duration,
          occurrences_count: self.issue.occurrences_count,
          occurrences_trigger: self.issue.occurrences_trigger
        })
        contacts = self.contacts.map { |contact| "#{contact.full_name} <#{contact.mail}>"}
        text_message = ERB.new(self.text_template).result(data.instance_eval {binding})
        html_message = ERB.new(self.html_template).result(data.instance_eval {binding})
        mail = Mail.new do
          from Notifu::CONFIG[:actors][:smtp][:from]
          subject "#{data[:status]}/#{data[:host]}/#{data[:service]}"
          to contacts
          text_part do
            body text_message
          end
          html_part do
            content_type 'text/html; charset=UTF-8'
            body html_message
          end
        end
        mail.delivery_method :sendmail
        mail.deliver
      end

      def text_template
        %{
<%= data[:message] %>

Notifu ID: <%= data[:notifu_id] %>
Host: <%= data[:host] %>
Service: <%= data[:service] %>
Status: <%= data[:status] %>
First event: <%= Time.at(data[:first_event]).to_s %>
Duration: <%= data[:duration] %>
Occurences: <%= data[:occurrences_count] %>/<%= data[:occurrences_trigger] %> (occured/trigger)
}
      end

      def html_template
        %{
<h3><%= data[:message] %></h3><br/>

<strong>Notifu ID: </strong><%= data[:notifu_id] %><br/>
<strong>Host: </strong><%= data[:host] %><br/>
<strong>Service: </strong><%= data[:service] %><br/>
<strong>Status: </strong><%= data[:status] %><br/>
<strong>First event: </strong><%= Time.at(data[:first_event]).to_s %><br/>
<strong>Duration: </strong><%= data[:duration] %><br/>
<strong>Occurences: </strong><%= data[:occurrences_count] %>/<%= data[:occurrences_trigger] %> (occured/trigger)<br/>
}
      end

    end
  end
end