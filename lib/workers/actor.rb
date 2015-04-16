require File.dirname(__FILE__) + '/sidekiq_init.rb'

$logger = Notifu::Logger.new "actor"


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
      load_data args
      act
    end

    def load_data args
      puts args.to_yaml
      self.issue = Issue.with(:notifu_id, args[0])
      self.contacts = args[1]
      puts
      puts self.name
    end

  end
end

# load all actors
Dir[File.dirname(__FILE__).sub(/\/lib\/workers$/, "/") + 'actors/*/actor.rb'].each do |file|
  require file
end
