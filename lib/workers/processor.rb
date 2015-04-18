require File.dirname(__FILE__) + '/sidekiq_init.rb'
require 'excon'

$logger = Notifu::Logger.new 'processor'

Sidekiq.configure_server do |config|
  config.redis = { url: Notifu::CONFIG[:redis_queues] }
  Sidekiq::Logging.logger = Log4r::Logger.new 'sidekiq'
  if Notifu::CONFIG[:logging][:syslog][:enabled]
    Sidekiq::Logging.logger.outputters = Log4r::SyslogOutputter.new 'sidekiq', ident: 'notifu-processor'
  else
    Sidekiq::Logging.logger.outputters = Log4r::Outputter.stdout
  end
  # Sidekiq::Logging.logger.formatter = Notifu::LogFormatter.new
  Sidekiq::Logging.logger.level = Log4r::DEBUG
end

Sidekiq.configure_client do |config|
  config.redis = { url: Notifu::CONFIG[:redis_queues] }
end

module Notifu
  class Processor
    include Sidekiq::Worker
    include Notifu::Util

    sidekiq_options :retry => true
    sidekiq_options :queue => "processor"

    attr_accessor :issue
    attr_accessor :event
    attr_accessor :now
    attr_accessor :processing_result

###################################################################
####### SIDEKIQ GLUE METHOD #######################################
###################################################################

    def perform *args
      t_start = Time.now.to_f*1000.0

      # read event
      self.event = Notifu::Model::Event.new args
      self.now = Time.now

      # try to check if we already know about the issue, otherwise save it into DB as a new one
      self.issue = Notifu::Model::Issue.with(:notifu_id, self.event.notifu_id)
      self.issue ||= Notifu::Model::Issue.create(self.event.data)

      # let the magic happen
      process!

      t_finish = Time.now.to_f*1000.0

      log "info", "JID-#{self.jid}: Task duration #{t_finish-t_start}ms"
    end

###################################################################
####### MAIN PROCESSING LOGIC #####################################
###################################################################

    def process!
      self.event.group_sla.each do |gs|

        # group related objects
        begin
          group = Notifu::Model::Group.with(:name, gs[:group])
          sla = Notifu::Model::Sla.with(:name, gs[:sla])
        rescue
          log "info", "#{self.event.notifu_id} [#{self.event.host}/#{self.event.service}/#{self.event.code.to_state}]: Object init failed. Is Notifu API running?"
          next
        end

        notified = {
          sla: String.new,
          group: String.new,
          actors: Array.new,
          contacts: Array.new,
          escalation_level: "none"
        }

        result = []

        # logic
        if enough_occurrences?
          result << "enough occurrences have passed"
          if ! silenced?
            result << "issue is not silenced"
            if duty_time? sla.timerange_values(self.now)
              result << "duty is active"
              if status_changed?
                result << "issue state has changed"
                notified = notify!(sla, group)
                result << "ACTION"
              else
                result << "issue state hasn't changed"
                case self.event.code
                when 0
                  result << "issue is in OK state" << "IDLE"
                when 1
                  result << "issue is in WARNING state"
                  if first_notification?(sla, group)
                    result << "issue is new"
                    notified = notify!(sla, group)
                    result << "ACTION"
                  else
                    result << "already notified" << "IDLE"
                  end
                when 2
                  result << "issue is not a warning"
                  if renotify?(sla, group)
                    result << "it's time to renotify"
                    notified = notify!(sla, group)
                    result << "ACTION"
                  else
                    result << "not yet time to renotify or escalate" << "IDLE"
                  end
                else
                  result << "unknown state (#{self.event.code})" << "IDLE"
                end
              end
            else
              result << "duty is not active at this time" << "IDLE"
            end
          else
            result << "issue is silenced" << "IDLE"
          end
        else
          result << "not enough occurrences of this event" << "IDLE"
        end

        # LOG
        log "info", "JID-#{self.jid}: (#{group.name}:#{sla.name}) NID-#{self.event.notifu_id} [#{self.event.host}/#{self.event.service}/#{self.event.code.to_state}]: " + result.join(' -> ')

        self.event.update_process_result!(notified)

        action_log_message = {
          logic: result.join(' -> '),
          result: result[-1],
          reason: result[-2],
          group: group.name,
          sla: sla.name,
          host: self.event.host,
          service: self.event.service,
          message: self.event.message,
          state: self.event.code.to_state,
          contacts: notified[:contacts].to_json,
          actors: notified[:actors].to_json,
          check_duration: self.event.duration,
          escalation_level: notified[:escalation_level].to_s,
          sidekiq_jid: self.jid,
          :"@timestamp" => self.now.iso8601,
        }
        action_log action_log_message
      end


      if self.event.process_result.length > 0
        self.issue.code = self.event.code
        self.issue.message = self.event.message
        self.issue.action = self.event.action
        self.issue.process_result = self.event.process_result
      end

      self.issue.occurrences_trigger = self.event.occurrences_trigger
      self.issue.occurrences_count = self.event.occurrences_count
      self.issue.time_last_event = self.event.time_last_event
      self.issue.sla = self.event.sla
      self.issue.aspiring_code = self.event.code
      self.issue.api_endpoint = self.event.api_endpoint
      self.issue.duration = self.event.duration

      self.issue.save
      # cleanup!
    end

###################################################################
####### NOTIFICATION METHOD (method for :process! ) ###############
###################################################################

    def notify! (sla, group)
      actors = []
      contacts = []
      escalation_level = "primary"
      sla_actors = eval(sla.actors)

      group.primary.each do |contact|
        contacts << contact.name
      end
      actors += sla_actors[:primary]

      # secondary escalation
      if escalate_to?(1, sla) && sla_actors[:secondary]
        group.secondary.each do |contact|
          contacts << contact.name
        end
        actors += sla_actors[:secondary]
        escalation_level = "secondary"
      end

      # tertiary escalation
      if escalate_to?(2, sla) && sla_actors[:tertiary]
        group.tertiary.each do |contact|
          contacts << contact.name
        end
        actors += sla_actors[:tertiary]
        escalation_level = "tertiary"
      end

      actors.each do |actor|
        job = Sidekiq::Client.push( 'class' => "Notifu::Actors::#{actor.camelize}",
                                    'args'  => [ self.event.notifu_id, contacts ],
                                    'queue' => "actor-#{actor}")
        log "info", "JID-#{self.jid}: (#{group.name}:#{sla.name}) NID-#{self.event.notifu_id} [#{self.event.host}/#{self.event.service}/#{self.event.code.to_state}]: taking action - actor: #{actor}; contacts: #{contacts.join(', ')}; escalation_level: #{escalation_level}"

      end

      self.issue.time_last_notified!(group.name, sla.name, Time.now.to_i)

      return { sla: sla.name, group: group.name, actors: actors, contacts: contacts, escalation_level: escalation_level }
    end


###################################################################
####### LOGIC BLOCK (methods for :process! ) ######################
###################################################################

    def enough_occurrences?
      self.event.occurrences_count >= self.event.occurrences_trigger ? true : false
    end

    def escalate_to?(level, sla)

      # escalation_interval = self.event.refresh
      # escalation_interval ||= sla.refresh
      escalation_interval = sla.refresh
      escalation_period = level.to_i * escalation_interval.to_i

      if ( self.issue.time_created.to_i + escalation_period.to_i ) <= ( self.now.to_i + 10 )
        return true
      else
        return false
      end
    end

    def silenced?
      begin
        sensu_api = Excon.get "#{self.event.api_endpoint}/stashes"
        stashes = JSON.parse sensu_api.body
      rescue
        stashes = []
        log "error", "Failed to get stashes #{self.event.api_endpoint}/stashes"
      end

      if self.event.service == "keepalive"
        path = "silence/#{self.event.host}"
      else
        path = "silence/#{self.event.host}/#{self.event.service}"
      end

      silenced = false
      stashes.each do |stash|
        silenced = true if stash["path"] == path
      end

      return silenced
    end

    def is_ok?
      self.event.code == 0 ? true : false
    end

    def is_warning?
      self.event.code == 1 ? true : false
    end

    def is_critical?
      self.event.code == 2 ? true : false
    end

    def first_notification? sla, group
      self.issue.time_last_notified?(group.name, sla.name) == nil ? true : false
    end

    def status_changed?
      self.event.code.to_i != self.issue.code.to_i ? true : false
    end

    def renotify? (sla, group)
      # t_renotify_int = self.event.refresh
      # t_renotify_int ||= sla.refresh
      t_renotify_int = sla.refresh
      t_last_notified = self.issue.time_last_notified?(group.name, sla.name)

      if ( t_last_notified.to_i + t_renotify_int.to_i ) <= ( self.now.to_i + 10 )
        return true
      else
        return false
      end
    end

    def duty_time? (timerange)
      case timerange
      when "ALWAYS"
        return true
      when "NEVER"
        return false
      when /([0-9]{2}):([0-9]{2})-([0-9]{2}):([0-9]{2})/
        t_duty_from = Time.local(self.now.year, self.now.month, self.now.day, timerange[0], timerange[1]).to_i
        t_duty_until = Time.local(self.now.year, self.now.month, self.now.day, timerange[2], timerange[3]).to_i
        if t_duty_from <= self.now.to_i <= t_duty_until
          return true
        else
          return false
        end
      else
        return true
      end
    end

###################################################################
####### HELPER BLOCK (methods for :process! ) #####################
###################################################################


    ##
    # cleanup method
    #
    def cleanup!
      if is_ok? && self.issue.action == "resolve"
        Notifu::Cleanup.perform_in(2.minutes, self.issue.notifu_id)
      end
    end


    ##
    # logging method
    #
    def log(prio, msg)
      $logger.log prio, msg
    end

    ##
    # action logging method
    #
    def action_log event
      $logger.action_log "processor", event
    end


  end
end