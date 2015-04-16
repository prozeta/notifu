module Notifu
  module Actors
    class Stdout < Notifu::Actor

      self.name = "stdout"
      self.desc = "STDOUT notifier, useful for debug only"
      self.retry = 0

      def act
        puts self.all_data.to_yaml
      end

    end
  end
end