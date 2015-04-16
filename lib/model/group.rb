module Notifu
  module Model
    class Group < Ohm::Model

      attribute :name
      set :primary, Notifu::Model::Contact
      set :secondary, Notifu::Model::Contact
      set :tertiary, Notifu::Model::Contact
      index :name
      unique :name

    end
  end
end