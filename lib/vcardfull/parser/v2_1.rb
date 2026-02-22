# frozen_string_literal: true

require "base64"

module Vcardfull
  class Parser
    # vCard 2.1 parser.
    # Documentation: https://web.archive.org/web/20120104222727/http://www.imc.org/pdi/vcard-21.txt
    #
    # Extends V30 with quoted-printable awareness and decoding support for
    # QUOTED-PRINTABLE and BASE64 encoded values. Removes encoding parameters
    # after decoding.
    class V21 < V30
      private
        def quoted_printable_aware?
          true
        end

        def decode(value_io, params)
          read_value(value_io) do |value|
            decoded = decode_value(value, params)
            params.delete("ENCODING")
            params.delete("CHARSET")
            decoded
          end
        end

        def decode_value(value, params)
          encoding = params["ENCODING"]&.upcase

          case encoding
          when "QUOTED-PRINTABLE"
            value.unpack1("M").force_encoding("UTF-8")
          when "BASE64", "B"
            Base64.decode64(value)
          else
            value
          end
        end

        def unescape(value)
          value
        end
    end
  end
end
