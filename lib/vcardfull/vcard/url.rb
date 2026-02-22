# frozen_string_literal: true

module Vcardfull
  class VCard
    # Represents a vCard URL property.
    class Url < Struct.new(:url, :label, :pref, :position, keyword_init: true)
      # Wraps raw data into a Url, returning the object unchanged if it is already one.
      #
      # @param data [Url, Hash] a Url instance or a Hash of keyword arguments.
      # @return [Url]
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
