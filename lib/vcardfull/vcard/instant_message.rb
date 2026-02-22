# frozen_string_literal: true

module Vcardfull
  class VCard
    # Represents a vCard IMPP (instant messaging) property.
    class InstantMessage < Struct.new(:uri, :label, :pref, :position, keyword_init: true)
      # Wraps raw data into an InstantMessage, returning the object unchanged if it is already one.
      #
      # @param data [InstantMessage, Hash] an InstantMessage instance or a Hash of keyword arguments.
      # @return [InstantMessage]
      def self.wrap(data)
        if data.is_a?(self)
          data
        else
          new(**data)
        end
      end
    end
  end
end
