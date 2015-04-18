module Notifu
  module Model
    class Contact < Ohm::Model

      attribute :name
      attribute :full_name
      attribute :cell
      attribute :mail
      attribute :jabber
      index :name
      unique :name

    end
  end
end