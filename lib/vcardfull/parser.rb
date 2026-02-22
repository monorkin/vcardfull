# frozen_string_literal: true

require "stringio"

module Vcardfull
  # Streaming vCard parser that supports versions 2.1, 3.0, and 4.0.
  #
  # Automatically detects the vCard version from the input and delegates to
  # the appropriate version-specific parser. Values smaller than a configurable
  # threshold are buffered in memory; larger values are written to temporary files.
  class Parser
    autoload :LineReader, "vcardfull/parser/line_reader"
    autoload :VCardHandler, "vcardfull/parser/vcard_handler"
    autoload :V21, "vcardfull/parser/v2_1"
    autoload :V30, "vcardfull/parser/v3_0"
    autoload :V40, "vcardfull/parser/v4_0"

    DEFAULT_LARGE_VALUE_THRESHOLD = 1 * 1024 * 1024 # 1 MB

    class << self
      # Parses vCard data and returns a VCard object.
      #
      # Detects the vCard version from the input and delegates to the
      # appropriate version-specific parser (V21, V30, or V40).
      #
      # @param input [String, IO] vCard data as a String or an IO-like object.
      # @param args [Hash] additional keyword arguments forwarded to the parser constructor.
      # @return [VCard] the parsed vCard.
      def parse(input, **args)
        io = input.is_a?(String) ? StringIO.new(input) : input
        version = detect_version(io)

        parser_class = case version
        when "2.1" then V21
        when "3.0" then V30
        else V40
        end

        parser_class.new(io, **args).parse
      end

      private
        def detect_version(io)
          version = nil

          io.each_line do |raw_line|
            line = raw_line.chomp("\r\n").chomp("\n").chomp("\r")

            if line =~ /\AVERSION:(.*)\z/i
              version = $1.strip
              break
            end
          end
          io.rewind

          version
        end
    end

    # Creates a new parser instance.
    #
    # @param input [String, IO] vCard data as a String or an IO-like object.
    # @param handler [VCardHandler, nil] a custom handler for property events. Defaults to a new VCardHandler.
    # @param large_value_threshold [Integer] byte size above which values are written to disk
    #   instead of being buffered in memory. Defaults to 1 MB.
    def initialize(input, handler: nil, large_value_threshold: DEFAULT_LARGE_VALUE_THRESHOLD)
      @io = input.is_a?(String) ? StringIO.new(input) : input
      @large_value_threshold = large_value_threshold
      @handler = handler || VCardHandler.new(unescape: method(:unescape))
    end

    # Runs the parser over the input and returns the constructed VCard.
    #
    # Iterates over each vCard property, dispatching events to the handler,
    # then returns the handler's result.
    #
    # @return [VCard] the parsed vCard.
    def parse
      each_property do |name, params, value, type:, pref:|
        @handler.on_property(name, params, value, type: type, pref: pref)
      end

      @handler.result
    end

    private
      def each_property
        line_reader = LineReader.new(
          @io,
          quoted_printable_aware: quoted_printable_aware?,
          large_value_threshold: @large_value_threshold
        )

        line_reader.each_line do |line_io|
          name, params, value_io = parse_line(line_io)

          unless name.nil?
            value = decode(value_io, params)
            type = extract_type(params)
            pref = extract_pref(params)

            yield name, params, value, type: type, pref: pref
          end
        end
      end

      def quoted_printable_aware?
        false
      end

      def decode(value_io, params)
        read_value(value_io) do |value|
          unescape(value)
        end
      end

      def read_value(value_io)
        if value_io.respond_to?(:read) && large_value?(value_io)
          value_io
        elsif value_io.respond_to?(:read)
          yield value_io.read
        else
          yield value_io
        end
      end

      def large_value?(value_io)
        (value_io.size - value_io.pos) > @large_value_threshold
      end

      def parse_line(line_io)
        property_with_params = +""

        while (char = line_io.getc)
          if char == ":"
            break
          else
            property_with_params << char
          end
        end

        if property_with_params.empty?
          nil
        else
          parts = property_with_params.split(";")
          name = parts.shift
          params = parse_params(parts)

          [ name, params, line_io ]
        end
      end

      def parse_params(parts)
        parts.each_with_object({}) do |part, params|
          if part.include?("=")
            key, val = part.split("=", 2)
            params[key.upcase] = val
          else
            params["TYPE"] = [ params["TYPE"], part ].compact.join(",")
          end
        end
      end

      def extract_type(params)
        params["TYPE"]&.split(",")&.first&.downcase
      end

      def extract_pref(params)
        params["PREF"]&.to_i
      end

      def unescape(value)
        value.gsub("\\n", "\n").gsub("\\N", "\n").gsub("\\,", ",").gsub("\\;", ";").gsub("\\\\", "\\")
      end
  end
end
