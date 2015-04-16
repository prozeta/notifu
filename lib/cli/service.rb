module Notifu
  module CLI
    class Service < Thor
      package_name "Notifu service"
      ##
      # API Service
      #
      desc "api", "Starts Notifu API"
      def api
        # Notifu::API.start
      end

      ##
      # Processor Service
      #
      desc "processor", "Starts Notifu processor"
      option :concurrency, :type => :numeric, :default => 1, :aliases => :c
      def processor
        puts "Starting #{options[:concurrency].to_s} processor(s)"
        system("bundle exec sidekiq -c " + options[:concurrency].to_s + " -r " + $basepath + "workers/processor.rb -q processor" )
      end

      ##
      # Actor Service
      #
      desc "actor", "Starts Notifu actor"
      option :actor, :type => :string, :default => nil, :aliases => :a
      option :concurrency, :type => :numeric, :default => 1, :aliases => :c
      def actor
        if ! options[:actor]
          puts "No actor name specified! Available actors:"
          Dir[$actorpath + "*/actor.rb"].each do |name|
            puts name.gsub(/.*actors\/([a-zA-Z0-9_]+)\/actor.rb/, "  \\1")
          end
        else
          if File.exists?($actorpath + options[:actor] + "/actor.rb") then
            puts "Starting #{options[:concurrency].to_s} '#{options[:actor]}' actor(s)"
            system("bundle exec sidekiq -c " + options[:concurrency].to_s + " -r " + $basepath + "workers/actor.rb -q actor-" + options[:actor])
          else
            STDERR.puts "Actor '#{options[:actor]}' does not exist"
            exit 1
          end
        end
      end

    end
  end
end