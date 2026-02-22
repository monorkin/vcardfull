# frozen_string_literal: true

require "stringio"
require "tempfile"

module Vcardfull
  class Parser
    # Streaming line reader that unfolds logical vCard lines from chunked IO input.
    #
    # Handles RFC 6350 line folding (continuation lines starting with a space or tab)
    # and vCard 2.1 quoted-printable soft line breaks. Values that exceed the
    # configured threshold are transparently promoted from in-memory StringIO
    # buffers to on-disk Tempfiles.
    class LineReader
      # Creates a new LineReader.
      #
      # @param io [IO] the input stream to read from.
      # @param large_value_threshold [Integer] byte size above which the internal
      #   buffer is promoted from a StringIO to a Tempfile.
      # @param quoted_printable_aware [Boolean] when +true+, treats trailing +=+
      #   as a quoted-printable soft line break (used for vCard 2.1).
      def initialize(io, large_value_threshold:, quoted_printable_aware: false)
        @io = io
        @quoted_printable_aware = quoted_printable_aware
        @large_value_threshold = large_value_threshold
      end

      # Yields each unfolded logical line as an IO object (StringIO or Tempfile).
      #
      # When called without a block, returns an Enumerator.
      #
      # @yield [IO] each unfolded logical line.
      # @return [Enumerator] if no block is given.
      def each_line
        return enum_for(:each_line) unless block_given?

        reset_state

        while (chunk = @io.read(@large_value_threshold))
          process_chunk(chunk) { |buffer| yield buffer }
        end

        if @has_content
          yield_buffered_line { |buffer| yield buffer }
        end
      end

      private
        def reset_state
          reset_buffer
          @state = :reading_content
          @has_content = false
          @last_character = nil
          @first_line = nil
        end

        def process_chunk(chunk, &block)
          @pos = 0

          while @pos < chunk.bytesize
            resolve_pending_state(chunk, &block)
            scan_content_run(chunk)
            detect_line_ending(chunk)
          end
        end

        def resolve_pending_state(chunk, &block)
          case @state
          when :after_carriage_return
            consume_optional_line_feed(chunk)
          when :after_line_break
            start_logical_line(chunk, &block)
          end
        end

        def consume_optional_line_feed(chunk)
          @state = :after_line_break
          @pos += 1 if chunk.getbyte(@pos) == 0x0A
        end

        def start_logical_line(chunk, &block)
          @state = :reading_content
          byte = chunk.getbyte(@pos)

          if byte == 0x20 || byte == 0x09
            @pos += 1
          elsif quoted_printable_soft_break?
            remove_trailing_soft_break_marker
          else
            yield_buffered_line(&block) if @has_content
            reset_buffer
            @first_line = nil
            @has_content = false
          end
        end

        def scan_content_run(chunk)
          run_start = @pos

          while @pos < chunk.bytesize
            byte = chunk.getbyte(@pos)
            break if byte == 0x0D || byte == 0x0A
            @pos += 1
          end

          if @pos > run_start
            content = chunk.byteslice(run_start, @pos - run_start)
            write_to_buffer(content)
            @last_character = content[-1]
            @has_content = true
            @first_line ||= capture_first_line
          end
        end

        def detect_line_ending(chunk)
          return if @pos >= chunk.bytesize

          byte = chunk.getbyte(@pos)

          if byte == 0x0D
            detect_carriage_return_ending(chunk)
          elsif byte == 0x0A
            detect_line_feed_ending
          end
        end

        def detect_carriage_return_ending(chunk)
          @pos += 1

          if @pos < chunk.bytesize
            @state = :after_line_break
            @pos += 1 if chunk.getbyte(@pos) == 0x0A
          else
            @state = :after_carriage_return
          end
        end

        def detect_line_feed_ending
          @state = :after_line_break
          @pos += 1
        end

        def quoted_printable_soft_break?
          @quoted_printable_aware && @last_character == "=" && quoted_printable_encoded?(@first_line)
        end

        def quoted_printable_encoded?(line)
          line&.match?(/;ENCODING=QUOTED-PRINTABLE/i)
        end

        def remove_trailing_soft_break_marker
          @buffer.truncate(@buffer.size - 1)
          @buffer.seek(0, IO::SEEK_END)
        end

        def yield_buffered_line
          @buffer.rewind
          yield @buffer
        end

        def capture_first_line
          @buffer.rewind
          line = @buffer.read
          @buffer.seek(0, IO::SEEK_END)
          line
        end

        def write_to_buffer(content)
          @buffer_size += content.bytesize
          promote_to_tempfile if !@promoted && @buffer_size > @large_value_threshold
          @buffer.write(content)
        end

        def promote_to_tempfile
          tempfile = Tempfile.new("vcard_line_reader")
          tempfile.binmode

          @buffer.rewind
          IO.copy_stream(@buffer, tempfile)

          @buffer = tempfile
          @promoted = true
        end

        def reset_buffer
          @promoted = false
          @buffer = StringIO.new
          @buffer_size = 0
        end
    end
  end
end
