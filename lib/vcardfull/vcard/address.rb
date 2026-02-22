# frozen_string_literal: true

module Vcardfull
  class VCard
    # Represents a vCard ADR property with structured address components.
    class Address < Struct.new(:po_box, :extended, :street, :locality, :region, :postal_code, :country, :label, :pref, :position, keyword_init: true)
      # Wraps raw data into an Address, returning the object unchanged if it is already one.
      #
      # @param data [Address, Hash] an Address instance or a Hash of keyword arguments.
      # @return [Address]
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
