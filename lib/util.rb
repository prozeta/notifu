module Notifu
  module Util

    def self.option args
      self.instance_variable_set args.keys.first, args.values.first
    end

  end
end
