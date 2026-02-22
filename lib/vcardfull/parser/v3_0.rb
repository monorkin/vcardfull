# frozen_string_literal: true

module Vcardfull
  class Parser
    # vCard 3.0 (RFC 2426) parser.
    # Documentation: https://datatracker.ietf.org/doc/html/rfc2426
    #
    # Overrides parameter parsing to handle the PREF keyword as a TYPE component
    # and to extract preference values from TYPE parameters.
    class V30 < Parser
      private
        def parse_params(parts)
          parts.each_with_object({}) do |part, params|
            if part.include?("=")
              key, val = part.split("=", 2)
              params[key.upcase] = val
            elsif part.upcase == "PREF"
              params["PREF"] = "1"
            else
              params["TYPE"] = [ params["TYPE"], part ].compact.join(",")
            end
          end
        end

        def extract_pref(params)
          types = params["TYPE"]&.split(",")&.map(&:downcase)

          if types&.include?("pref")
            1
          else
            params["PREF"]&.to_i
          end
        end

        def extract_type(params)
          params["TYPE"]&.split(",")&.map(&:downcase)&.reject { |t| t == "pref" }&.first
        end
    end
  end
end
