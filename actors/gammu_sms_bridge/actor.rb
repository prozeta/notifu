module Notifu::Actors
  class GammuSmsBridge < Notifu::Actor

    self.name = "gammu_sms_bridge"
    self.desc = "Old-school NetCat-like SMS bridge to Gammu"
    self.retry = 3

    def act

      # NEED TO ITERATE OVER CONTACTS

      # cell = self.contact.cell
      # template = ERB.new File.new("sms.erb").read, nil, "%"
      # message = template.result(self.issue)

      # # send message to sms-bridge
      # socket = TCPSocket.new
      # socket.send cell + "--" + message
      # socket.close
      # socket = nil
    end

  end
end