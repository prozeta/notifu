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
      attribute :time_last_event
      attribute :time_last_notified
      attribute :time_created
      attribute :sla
      attribute :action
      attribute :code
      attribute :message
      attribute :process_result
      index :notifu_id

      def last_notified sla
        begin
          @time_last_notified[sla].to_i
        rescue
          0
        end
      end

      def last_notified= (sla, time)
        @time_last_notified[sla] = time
      end

      def create_from_event event
        event.each { |name, value| instance_variable_set(name, value) }
        self.save
      end

    end
  end
end
