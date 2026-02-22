# frozen_string_literal: true

module Vcardfull
  class Parser
    # SAX-style event handler that accumulates parsed vCard properties and builds
    # a VCard object. Used internally by the Parser to map raw property events
    # to structured VCard attributes.
    class VCardHandler
      STRUCTURED_NAME_PARTS = %i[family_name given_name additional_names honorific_prefix honorific_suffix].freeze

      ADDRESS_PARTS = %i[po_box extended street locality region postal_code country].freeze

      # Creates a new VCardHandler.
      #
      # @param unescape [#call] a callable that unescapes vCard backslash sequences
      #   in property values (e.g. +\\n+ to newline).
      def initialize(unescape:)
        @unescape = unescape
        @attributes = {
          emails: [],
          phones: [],
          addresses: [],
          urls: [],
          instant_messages: [],
          custom_properties: []
        }
        @position_counters = Hash.new(0)
      end

      # Dispatches a parsed vCard property to the appropriate handler method.
      #
      # @param name [String] the property name (e.g. "EMAIL", "TEL", "FN").
      # @param params [Hash] the property parameters (e.g. {"TYPE" => "work"}).
      # @param value [String, IO] the property value, either a String or an IO for large values.
      # @param type [String, nil] the extracted TYPE parameter value (e.g. "work", "home").
      # @param pref [Integer, nil] the preference order, if specified.
      def on_property(name, params, value, type:, pref:)
        case name.upcase
        when "BEGIN", "END"
          # skip
        when "VERSION"
          on_version(value)
        when "UID"
          on_uid(value)
        when "FN"
          on_formatted_name(value)
        when "N"
          on_structured_name(value)
        when "KIND"
          on_kind(value)
        when "NICKNAME"
          on_nickname(value)
        when "BDAY"
          on_birthday(value)
        when "ANNIVERSARY"
          on_anniversary(value)
        when "GENDER"
          on_gender(value)
        when "NOTE"
          on_note(value)
        when "PRODID"
          on_product_id(value)
        when "EMAIL"
          on_email(value, type: type, pref: pref)
        when "TEL"
          on_phone(value, type: type, pref: pref)
        when "ADR"
          on_address(value, type: type, pref: pref)
        when "URL"
          on_url(value, type: type, pref: pref)
        when "IMPP"
          on_instant_message(value, type: type, pref: pref)
        else
          on_custom_property(name, value, params)
        end
      end

      # Returns the constructed VCard from all accumulated properties.
      #
      # @return [VCard] the built vCard object.
      def result
        VCard.new(**@attributes)
      end

      private
        def on_version(value)
          @attributes[:version] = value
        end

        def on_uid(value)
          @attributes[:uid] = value
        end

        def on_formatted_name(value)
          @attributes[:formatted_name] = @unescape.call(value)
        end

        def on_structured_name(value)
          parts = split_structured(value)
          STRUCTURED_NAME_PARTS.each_with_index do |key, i|
            val = @unescape.call(parts[i].to_s)
            @attributes[key] = val.empty? ? nil : val
          end
        end

        def on_kind(value)
          @attributes[:kind] = value.downcase
        end

        def on_nickname(value)
          @attributes[:nickname] = @unescape.call(value)
        end

        def on_birthday(value)
          @attributes[:birthday] = value
        end

        def on_anniversary(value)
          @attributes[:anniversary] = value
        end

        def on_gender(value)
          @attributes[:gender] = value
        end

        def on_note(value)
          @attributes[:note] = @unescape.call(value)
        end

        def on_product_id(value)
          @attributes[:product_id] = value
        end

        def on_email(value, type:, pref:)
          @attributes[:emails] << {
            address: value,
            label: type,
            pref: pref,
            position: next_position(:email)
          }
        end

        def on_phone(value, type:, pref:)
          @attributes[:phones] << {
            number: value,
            label: type,
            pref: pref,
            position: next_position(:phone)
          }
        end

        def on_address(value, type:, pref:)
          parts = split_structured(value)
          addr = {
            label: type,
            pref: pref,
            position: next_position(:address)
          }
          ADDRESS_PARTS.each_with_index do |key, i|
            val = @unescape.call(parts[i].to_s)
            addr[key] = val.empty? ? nil : val
          end
          @attributes[:addresses] << addr
        end

        def on_url(value, type:, pref:)
          @attributes[:urls] << {
            url: value,
            label: type,
            pref: pref,
            position: next_position(:url)
          }
        end

        def on_instant_message(value, type:, pref:)
          @attributes[:instant_messages] << {
            uri: value,
            label: type,
            pref: pref,
            position: next_position(:im)
          }
        end

        def on_custom_property(name, value, params)
          @attributes[:custom_properties] << {
            name: name.upcase,
            value: value,
            params: params_string(params),
            position: next_position(:custom)
          }
        end

        def next_position(counter)
          position = @position_counters[counter]
          @position_counters[counter] += 1
          position
        end

        def split_structured(value)
          value.split(/(?<!\\);/, -1)
        end

        def params_string(params)
          return nil if params.empty?
          params.map { |k, v| "#{k}=#{v}" }.join(";")
        end
    end
  end
end
