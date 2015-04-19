require_relative "sidekiq_init"

$logger = Notifu::Logger.new 'actor'

Sidekiq.configure_server do |config|
  config.redis = { url: Notifu::CONFIG[:redis_queues] }
  Sidekiq::Logging.logger = Log4r::Logger.new 'sidekiq'
  Sidekiq::Logging.logger.outputters = Log4r::SyslogOutputter.new 'sidekiq', ident: 'notifu-actor'
  # Sidekiq::Logging.logger.formatter = Notifu::LogFormatter.new
  Sidekiq::Logging.logger.level = Log4r::DEBUG
end

Sidekiq.configure_client do |config|
  config.redis = { url: Notifu::CONFIG[:redis_queues] }
end


module Notifu

  class Actor
    include Notifu::Util
    include Sidekiq::Worker

    attr_accessor :issue
    attr_accessor :contacts

    class << self
      attr_accessor :name
      attr_accessor :desc
      attr_accessor :retry
    end

    # `act` function must be defined in child classes
    # (provides notification actors modularity)
    #
    def act
      exit 1
    end

    sidekiq_options :queue => "actor-#{self.name}"
    sidekiq_options :retry => self.retry

    def perform *args
      sleep 2
      load_data args
      act
    end

    def load_data args
      self.issue = Notifu::Model::Issue.with(:notifu_id, args[0])
      self.contacts = args[1].map { |contact| Notifu::Model::Contact.with(:name, contact) }
    end

  end
end

# load all actors
Dir[File.dirname(__FILE__).sub(/\/lib\/workers$/, "/") + 'actors/*.rb'].each do |file|
  require file
end
