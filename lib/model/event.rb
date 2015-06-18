module Notifu
  module Model
    class Event
      include Notifu::Util
      attr_reader :notifu_id
      attr_reader :host
      attr_reader :address
      attr_reader :service
      attr_reader :occurrences_trigger
      attr_reader :occurrences_count
      attr_reader :interval
      attr_reader :time_last_event
      attr_reader :time_last_notified
      attr_reader :time_created
      attr_reader :sgs
      attr_reader :action
      attr_reader :code
      attr_reader :aspiring_code
      attr_reader :message
      attr_reader :api_endpoint
      attr_reader :duration
      attr_reader :unsilence
      attr_reader :refresh
      attr_accessor :process_result

      def initialize args
        payload = args.first
        payload.each { |name, value| instance_variable_set("@#{name}", value) }
        @time_last_notified = Hash.new.to_json.to_s
        @time_created = self.time_last_event
        @aspiring_code = self.code
        @occurrences_trigger ||= 1
        @refresh ||= nil
        @unsilence ||= true
      end

      def group_sla
        self.sgs.map { |gs| Hash[:group, gs.split(':')[0], :sla, gs.split(':')[1]] }
      end

      def data
        @data ||= Hash[ instance_variables.map { |var| [var.to_s.sub(/^@/,""), instance_variable_get(var)] } ]
      end

      def update_process_result!(obj)
        self.process_result ||= JSON.generate(Array.new)
        self.process_result = JSON.generate(JSON.parse(self.process_result) + [ obj ])
      end

    end
  end
end
