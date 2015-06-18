module Notifu
  module Model
    class Issue < Ohm::Model
      include Notifu::Util
      attribute :notifu_id
      attribute :host
      attribute :address
      attribute :service
      attribute :occurrences_trigger
      attribute :occurrences_count
      attribute :interval
      attribute :refresh
      attribute :time_last_event
      attribute :time_last_notified
      attribute :time_created
      attribute :sgs
      attribute :action
      attribute :code
      attribute :aspiring_code
      attribute :message
      attribute :process_result
      attribute :api_endpoint
      attribute :duration
      attribute :unsilence
      index :notifu_id
      index :host
      index :service
      unique :notifu_id


      def time_last_notified? (group_name, sla_name)
        begin
          JSON.parse(self.time_last_notified)["#{group_name}:#{sla_name}"]
        rescue
          0
        end
      end

      def time_last_notified! (group_name, sla_name, time)
        obj = JSON.parse(self.time_last_notified)
        self.time_last_notified = JSON.generate(obj.merge({ "#{group_name}:#{sla_name}" => time }))
      end

      def create_from_event event
        event.each { |name, value| instance_variable_set(name, value) }
        self.save
      end

    end
  end
end
