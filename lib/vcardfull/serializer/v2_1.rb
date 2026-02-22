# frozen_string_literal: true

module Vcardfull
  class Serializer
    # vCard 2.1 serializer.
    #
    # Overrides parameter formatting to use bare type values (e.g. +;WORK+
    # instead of +;TYPE=work+), disables backslash escaping, and applies
    # quoted-printable encoding for non-ASCII values.
    class V21 < Serializer
      private
        def build_params(label: nil, pref: nil)
          parts = []
          parts << label.upcase if label && !label.to_s.empty?
          parts << "PREF" if pref && !pref.to_s.empty?

          if parts.any?
            ";#{parts.join(";")}"
          else
            ""
          end
        end

        def escape(value)
          value
        end

        def fn_line
          encode("FN", @attributes.formatted_name.to_s)
        end

        def n_line
          parts = [
            @attributes.family_name,
            @attributes.given_name,
            @attributes.additional_names,
            @attributes.honorific_prefix,
            @attributes.honorific_suffix
          ]

          encode("N", parts.map(&:to_s).join(";"))
        end

        def encode(name, value)
          if needs_quoted_printable_encoding?(value)
            "#{name};ENCODING=QUOTED-PRINTABLE;CHARSET=UTF-8:#{quoted_printable_encode(value)}"
          else
            "#{name}:#{value}"
          end
        end

        def simple_properties(lines)
          %i[nickname birthday anniversary gender note product_id].each do |key|
            value = @attributes[key]
            lines << encode(PROPERTY_NAMES[key], value.to_s) if value && !value.to_s.empty?
          end
        end

        def needs_quoted_printable_encoding?(value)
          !value.ascii_only?
        end

        def quoted_printable_encode(value)
          encoded = [ value ].pack("M")
          encoded.gsub!(/=\n\z/, "")
          encoded.gsub!(/\n/, "\r\n")
          encoded
        end
    end
  end
end
