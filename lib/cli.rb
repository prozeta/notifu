module Notifu
  module CLI
    class Root < Thor
      package_name "Notifu"

      desc "object SUBCOMMAND", "Runtime configuration object management (SLAs, contacts & groups)"
      subcommand "object", Object

      desc "service SUBCOMMAND", "Notifu service processes"
      subcommand "service", Service
    end
  end
end