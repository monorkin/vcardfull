# frozen_string_literal: true

module Vcardfull
  # Serializes a VCard object into vCard format (RFC 6350).
  #
  # Produces a complete vCard string with BEGIN/END delimiters, CRLF line
  # endings, and properly escaped property values.
  class Serializer
    autoload :V21, "vcardfull/serializer/v2_1"

    PROPERTY_NAMES = {
      version: "VERSION",
      kind: "KIND",
      formatted_name: "FN",
      nickname: "NICKNAME",
      birthday: "BDAY",
      anniversary: "ANNIVERSARY",
      gender: "GENDER",
      note: "NOTE",
      product_id: "PRODID"
    }.freeze

    # Creates a new Serializer.
    #
    # @param attributes [VCard] the vCard object to serialize.
    def initialize(attributes)
      @attributes = attributes
    end

    # Serializes the vCard to a vCard format string.
    #
    # @return [String] the vCard data with CRLF line endings.
    def to_vcf
      lines = []
      lines << "BEGIN:VCARD"
      lines << "VERSION:#{@attributes.version || "4.0"}"
      lines << uid_line
      lines << n_line if has_structured_name?
      lines << fn_line
      lines << kind_line if @attributes.kind

      simple_properties(lines)
      emails(lines)
      phones(lines)
      addresses(lines)
      urls(lines)
      instant_messages(lines)
      custom_properties(lines)

      lines << "END:VCARD"
      lines.compact.join("\r\n") + "\r\n"
    end

    private
      def uid_line
        "UID:#{@attributes.uid}"
      end

      def n_line
        parts = [
          @attributes.family_name,
          @attributes.given_name,
          @attributes.additional_names,
          @attributes.honorific_prefix,
          @attributes.honorific_suffix
        ]
        "N:#{parts.map { |p| escape(p.to_s) }.join(";")}"
      end

      def has_structured_name?
        %i[family_name given_name additional_names honorific_prefix honorific_suffix].any? do |key|
          value = @attributes[key]
          value.is_a?(String) ? !value.empty? : !value.nil?
        end
      end

      def fn_line
        "FN:#{escape(@attributes.formatted_name.to_s)}"
      end

      def kind_line
        "KIND:#{@attributes.kind}"
      end

      def simple_properties(lines)
        %i[nickname birthday anniversary gender note product_id].each do |key|
          value = @attributes[key]
          if value && !value.to_s.empty?
            lines << "#{PROPERTY_NAMES[key]}:#{escape(value.to_s)}"
          end
        end
      end

      def emails(lines)
        Array(@attributes.emails).each do |email|
          params = build_params(label: email.label, pref: email.pref)
          lines << "EMAIL#{params}:#{email.address}"
        end
      end

      def phones(lines)
        Array(@attributes.phones).each do |phone|
          params = build_params(label: phone.label, pref: phone.pref)
          lines << "TEL#{params}:#{phone.number}"
        end
      end

      def addresses(lines)
        Array(@attributes.addresses).each do |addr|
          params = build_params(label: addr.label, pref: addr.pref)
          parts = [
            addr.po_box,
            addr.extended,
            addr.street,
            addr.locality,
            addr.region,
            addr.postal_code,
            addr.country
          ]
          lines << "ADR#{params}:#{parts.map { |p| escape(p.to_s) }.join(";")}"
        end
      end

      def urls(lines)
        Array(@attributes.urls).each do |url|
          params = build_params(label: url.label, pref: url.pref)
          lines << "URL#{params}:#{url.url}"
        end
      end

      def instant_messages(lines)
        Array(@attributes.instant_messages).each do |im|
          params = build_params(label: im.label, pref: im.pref)
          lines << "IMPP#{params}:#{im.uri}"
        end
      end

      def custom_properties(lines)
        Array(@attributes.custom_properties).each do |prop|
          value = prop.value.respond_to?(:read) ? prop.value.tap(&:rewind).read : prop.value
          params_str = prop.params.to_s
          if params_str.empty?
            lines << "#{prop.name}:#{value}"
          else
            lines << "#{prop.name};#{params_str}:#{value}"
          end
        end
      end

      def build_params(label: nil, pref: nil)
        parts = []
        parts << "TYPE=#{label}" if label && !label.to_s.empty?
        parts << "PREF=#{pref}" if pref && !pref.to_s.empty?

        if parts.any?
          ";#{parts.join(";")}"
        else
          ""
        end
      end

      def escape(value)
        value.gsub("\\", "\\\\\\\\").gsub(",", "\\,").gsub("\n", "\\n")
      end
  end
end
