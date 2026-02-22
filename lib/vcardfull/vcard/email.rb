# frozen_string_literal: true

module Vcardfull
  class VCard
    # Represents a vCard EMAIL property.
    class Email < Struct.new(:address, :label, :pref, :position, keyword_init: true)
      # Wraps raw data into an Email, returning the object unchanged if it is already one.
      #
      # @param data [Email, Hash] an Email instance or a Hash of keyword arguments.
      # @return [Email]
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
