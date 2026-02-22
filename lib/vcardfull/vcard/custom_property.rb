# frozen_string_literal: true

module Vcardfull
  class VCard
    # Represents a non-standard or extension vCard property (e.g. X-properties).
    class CustomProperty < Struct.new(:name, :value, :params, :position, keyword_init: true)
      # Wraps raw data into a CustomProperty, returning the object unchanged if it is already one.
      #
      # @param data [CustomProperty, Hash] a CustomProperty instance or a Hash of keyword arguments.
      # @return [CustomProperty]
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
