module Notifu
  module Model
    class Sla < Ohm::Model

      attribute :name
      attribute :timeranges
      attribute :refresh
      attribute :actors
      index :name
      unique :name

      def timerange_values (now=Time.now)
        dow = now.wday - 1
        dow = 6 if dow < 0
        JSON.parse(self.timeranges)[dow]
      end

    end
  end
end