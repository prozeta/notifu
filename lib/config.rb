module Notifu
  class Config

    attr_reader :config

    @@config_path = "/etc/notifu/"

    def initialize
      begin
        @config = YAML.load_file(@@config_path + 'notifu.yaml')
      rescue
        raise "Failed to load main config file"
      end
    end

    def get
      @get ||= self.config.deep_symbolize_keys
    end

    # def ohm_init
    #   contacts_init
    #   slas_init
    #   groups_init
    # end

    # def contacts_init
    #   Dir[@@config_path + 'contacts/*.yaml'].each do |path|
    #     cfg = YAML.load_file path
    #     contact = Contact.create cfg
    #   end
    # end

    # def slas_init
    #   Dir[@@config_path + 'slas/*.yaml'].each do |path|
    #     cfg = YAML.load_file path
    #     sla = SLA.create cfg
    #   end
    # end

    # def groups_init
    #   Dir[@@config_path + 'groups/*.yaml'].each do |path|
    #     cfg = YAML.load_file path
    #     group = Group.create cfg[:name]
    #   end
    # end


  end
end