module Notifu
  module Actors
    class Smtp < Notifu::Actor

      self.name = "smtp"
      self.desc = "SMTP notifier"

      def run
      end

      def template
        %{
Subject: <%= notification[:status][:message] %>

<h3><%= notification[:status][:message] %></h3><br/>

<strong>Host: </strong><%= notification[:subject][:host] %> (<%= notification[:subject][:address] %>)<br/>
<strong>Service: </strong><%= notification[:subject][:service] %><br/>
<strong>State change: </strong><%= status_names[last_code] %> -> <%= status_names[notification[:status][:code]] %><br/>
<strong>Last event: </strong><%= Time.at(notification[:time][:last_event]).to_s %><br/>
<strong>Last notifiction: </strong><%= last_notification %><br/>
<strong>Occurences: </strong><%= notification[:status][:occurences] %>/<%= notification[:subject][:occurences] %> (occured/trigger)<br/>
EOF
        }

    end
  end
end