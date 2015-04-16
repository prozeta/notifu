module Notifu
  module Model
    class Group < Ohm::Model

      attribute :name
      set :primary, Notifu::Contact
      set :secondary, Notifu::Contact
      set :tertiary, Notifu::Contact
      index :name
      unique :name

    end
  end
end