require 'redis'

module Sensu::Extension
  class Notifu < Handler

    def definition
      {
        type: 'extension',
        name: 'notifu'
      }
    end

    def name
      definition[:name]
    end

    def options
      return @options if @options
      @options = {
        :host    => '127.0.0.1',
        :port    => 6379,
        :channel => "processor",
        :db      => 4
      }
      if @settings[:notifu].is_a?(Hash)
        @options.merge!(@settings[:notifu])
      end
      @options
    end

    def description
      'Notifu handler for Sensu Server'
    end

    def post_init
      @redis = Sensu::Redis.connect(options)
      @redis.on_error do |error|
        @logger.warn('Notifu Redis instance not available on ' + options[:host] + ':' + options[:port])
      end
    end

    def run event
      begin
        if event[:check][:name] == "keepalive"
          sla = event[:client][:sla]
        else
          sla = event[:check][:sla]
        end
      rescue
        @logger.warn('No SLA, dropping event')
        yield ''
      end

      payload = {
        notifu_id: event[:id],
        host: event[:client][:name],
        address: event[:client][:address],
        service: event[:check][:name],
        occurrences_trigger: event[:check][:occurrences],
        occurrences_count: event[:occurrences],
        time_last_event: event[:check][:executed],
        sla: sla,
        action: event[:action],
        code: event[:check][:status],
        message: event[:check][:output],
        api_endpoint: "http://" + @settings[:api][:host] + ":" + @settings[:api][:port] + "/"
      }

      job = {
        'class' => 'Notifu::Processor',
        'args' => payload,
        'jid' => SecureRandom.hex(12),
        'retry' => true,
        'enqueued_at' => Time.now.to_f
      }

      begin
        @redis.lpush("default:queue:processor", JSON.dump(job))
        @logger.info('Event dispatched to Notifu')
      rescue Exception => e
        @logger.error('Event dispatch to Notifu failed: ' + e)
      end
    end

  end
end