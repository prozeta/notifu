module Notifu
  class Config

    attr_reader :config

    @@config_path = "/etc/notifu/"

    def initialize
      begin
        @config = YAML.load_file(@@config_path + 'notifu.yaml')
      rescue
        raise "Failed to load main config file!"
      end
    end

    def get
      @get ||= self.config.deep_symbolize_keys
    end

    def ohm_init
      contacts_init
      slas_init
      groups_init
    end

    def contacts_init
      Dir[@@config_path + 'contacts/*.yaml'].each do |path|
        cfg = YAML.load_file(path).deep_symbolize_keys
        begin
            Notifu::Model::Contact.with(:name, cfg[:name]).update(cfg)
            puts "Updated contact '#{cfg[:name]}'."
        rescue
            Notifu::Model::Contact.create(cfg).save
            puts "Created contact '#{cfg[:name]}'."
        end
      end
    end

    def slas_init
      Dir[@@config_path + 'slas/*.yaml'].each do |path|
        cfg = YAML.load_file(path).deep_symbolize_keys
        begin
            Notifu::Model::Sla.with(:name, cfg[:name]).update(cfg)
            puts "Updated SLA '#{cfg[:name]}'."
        rescue
            Notifu::Model::Sla.create(cfg).save
            puts "Created SLA '#{cfg[:name]}'."
        end
      end
    end

    def groups_init
      Dir[@@config_path + 'groups/*.yaml'].each do |path|
        cfg = YAML.load_file(path).deep_symbolize_keys
        begin
          group = Notifu::Model::Group.create(name: cfg[:name])
          puts "Created group '#{cfg[:name]}'."
        rescue
          group = Notifu::Model::Group.with(:name, cfg[:name])
          puts "Found group '#{cfg[:name]}'."
        end

        contacts = Array.new

        cfg[:primary].each do |contact_id|
          begin
            contacts << Notifu::Model::Contact.with(:name, contact_id)
            puts "Contact '#{contact_id}' accepted as primary."
          rescue
            puts "Failed to load primary contact '#{contact_id}'."
          end
        end

        group.primary.replace(contacts)
        group.save
        puts "Primary contacts for group '#{cfg[:name]}' updated."

        if cfg[:secondary].is_a? Array
          contacts = Array.new

          cfg[:secondary].each do |contact_id|
            begin
              contacts << Notifu::Model::Contact.with(:name, contact_id)
              puts "Contact '#{contact_id}' accepted as secondary."
            rescue
              puts "Failed to load secondary contact '#{contact_id}'."
              exit 1
            end
          end

          group.secondary.replace(contacts)
          group.save
          puts "Secondary contacts for group '#{cfg[:name]}' updated."

          if cfg[:tertiary].is_a? Array
            contacts = Array.new

            cfg[:tertiary].each do |contact_id|
              begin
                contacts << Notifu::Model::Contact.with(:name, contact_id)
                puts "Contact '#{contact_id}' accepted as tertiary."
              rescue
                puts "Failed to load tertiary contact '#{contact_id}'."
                exit 1
              end
            end

            group.tertiary.replace(contacts)
            group.save
            puts "Tertiary contacts for group '#{cfg[:name]}' updated."
          else
            group.tertiary.replace([])
          end
        else
          group.secondary.replace([])
        end
      end
    end
  end
end