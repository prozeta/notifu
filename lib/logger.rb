module Notifu
  class Logger

    attr_reader :syslog_enabled
    attr_reader :elasticsearch_enabled
    attr_reader :es
    attr_reader :syslog

    LEVELS = [ "debug",
               "info",
               "notice",
               "warning",
               "error",
               "critical",
               "alert",
               "emergency" ]

    def initialize (mod)
      @syslog_enabled = Notifu::CONFIG[:logging][:syslog][:enabled]
      @elasticsearch_enabled = Notifu::CONFIG[:logging][:elasticsearch][:enabled]

      @logger = Log4r::Logger.new 'notifu'

      if self.syslog_enabled
        begin
          @logger.outputters = Log4r::SyslogOutputter.new "notifu", ident: "notifu-#{mod}"
          log "info", "Syslog socket opened"
        rescue
          @logger.outputters = Log4r::Outputter.stdout
          log "error", "Failed to open local syslog socket, using STDOUT"
        end
      else
        log "info", "Syslog disabled"
        @logger.outputters = Log4r::Outputter.stdout
      end

      if self.elasticsearch_enabled
        begin
          @es = Elasticsearch::Client.new hosts: Notifu::CONFIG[:logging][:elasticsearch][:conn], retry_on_failure: false, transport_options: { request: { timeout: Notifu::CONFIG[:logging][:elasticsearch][:timeout] || 10 } }
          log "info", "Action log output to ElasticSearch - " + Notifu::CONFIG[:logging][:elasticsearch][:conn].to_json
        rescue
          @es = false
          log "error", "Failed to connect to ElasticSearch"
          exit 1
        end
      else
        log "info", "ElasticSearch action logging disabled"
        @es = false
      end

    end

    def action_log (type, event)
      if self.elasticsearch_enabled && self.es
        index_name = "notifu-" + Time.now.strftime("%Y.%m.%d").to_s
        begin
          self.es.index index: index_name, type: type, body: event
        rescue Faraday::TimeoutError
          log "error", "Action log action failed: ElasticSearch timeout"
          log "info", "Action log: (#{type}) #{event.to_json}"
        end
      else
        log "debug", "Action log: #{type}"
        log "debug", "Action log: (#{type}) #{event.to_json}"
      end
    end

    def log (prio, msg)
      @logger.send prio.to_sym, msg
    end

  end


  # class LogFormatter < Log4r::Formatter
  #   def format(event)
  #     event.to_yaml
  #   end
  # end

  # "#{time.utc.iso8601(3)} notifu-sidekiq[#{::Process.pid}]: #{context} (TID-#{Thread.current.object_id.to_s(36)}) #{severity}: #{message}\n"

end
