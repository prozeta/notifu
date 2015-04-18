module Notifu
  module CLI
    class Object < Thor
      package_name "Notifu object configuration"
      ##
      # DB Sync task
      #
      desc "sync", "Syncs locally defined config objects with DB"
      def sync
        puts "Syncing data with Redis..."
        Notifu::Config.new.ohm_init
        puts "...done"
      end

      ##
      # Configure SLA objects
      #
      desc "sla ACTION", "Manage SLAs"
      def sla(name)
      end

      ##
      # Configure contact objects
      #
      desc "contact ACTION", "Manage contacts"
      def contact(name)
      end

      ##
      # Configure group objects
      #
      desc "group ACTION", "Manage groups"
      def group(name)
      end
    end
  end
end