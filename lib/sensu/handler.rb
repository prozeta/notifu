require 'sensu/redis'
require 'digest'
require 'multi_json'

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
        :db      => 2
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

      if @redis
        yield(@redis)
      else
        Sensu::Redis.connect(options) do |connection|
          connection.auto_reconnect = false
          connection.reconnect_on_error = true
          connection.on_error do |error|
            @logger.warn(error)
          end
          @redis = connection
        end
      end
      @redis.sadd("queues", "processor")
    end

    def run(event_data)
      event = MultiJson.load(event_data, { :symbolize_keys => true })
      notifu_id = Digest::SHA256.hexdigest("#{event[:client][:name]}:#{event[:client][:address]}:#{event[:check][:name]}").to_s[-10,10]

      if event[:check][:name] == "keepalive"
        sgs = event[:client][:sgs]
        sgs ||= event[:client][:sla]
      else
        sgs = event[:check][:sgs]
        sgs ||= event[:check][:sla]
      end

      payload = {
        notifu_id: notifu_id,
        host: event[:client][:name],
        address: event[:client][:address],
        service: event[:check][:name],
        occurrences_trigger: event[:check][:occurrences],
        occurrences_count: event[:occurrences],
        interval: event[:check][:interval] || 0,
        time_last_event: event[:check][:executed],
        sgs: sgs,
        action: event[:action],
        code: event[:check][:status],
        message: event[:check][:output],
        duration: event[:check][:duration],
        api_endpoint: "http://" + @settings[:api][:host].to_s + ":" + @settings[:api][:port].to_s
      }

      job = {
        'class' => 'Notifu::Processor',
        'args' => [ payload ],
        'jid' => SecureRandom.hex(12),
        'retry' => true,
        'enqueued_at' => Time.now.to_f
      }

      begin
        @redis.lpush("queue:processor", MultiJson.dump(job))
      rescue Exception => e
        yield "failed to send event to Notifu #{e.message}", 1
      end

      yield "sent event to Notifu #{notifu_id}", 0
    end

    def stop
      yield
    end

  end
end

