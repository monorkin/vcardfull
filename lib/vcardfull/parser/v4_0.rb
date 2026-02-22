# frozen_string_literal: true

module Vcardfull
  class Parser
    # vCard 4.0 (RFC 6350) parser.
    # Documentation: https://datatracker.ietf.org/doc/html/rfc6350
    #
    # Uses the base Parser behavior without any version-specific overrides.
    class V40 < Parser
    end
  end
end
