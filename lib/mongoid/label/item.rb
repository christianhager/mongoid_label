module Mongoid
  module Label
    class Item
      include Mongoid::Document
      field :name, :type => String
      embedded_in :labelable, polymorphic: true
    end
  end
end