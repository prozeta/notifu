module Notifu
  module Actors
    class GammuSmsBridge < Notifu::Actor

      self.name = "gammu_sms_bridge"
      self.desc = "Old-school NetCat-like SMS bridge to Gammu"
      self.retry = 3

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
        message = ERB.new(self.template).result(data.instance_eval {binding})

        self.contacts.each do |contact|
          cell = contact.cell
          template = ERB.new File.new("sms.erb").read, nil, "%"
          message = "template.result(self.issue)"

          # send message to sms-bridge
          socket = TCPSocket.new Notifu::CONFIG[:actors][:gammu_sms_bridge][:host], Notifu::CONFIG[:actors][:gammu_sms_bridge][port]
          socket.send contact.cell.to_s + "--" + message
          socket.close
          socket = nil
        end
      end

      def template
          "<%= data[:status] %> [<%= data[:host] %>/<%= data[:service] %>]: (<%= data[:message] %>) <%= data[:duration] %> [<%= data[:notifu_id] %>]"
      end
    end
  end
end