require_relative "../../test_helper"
require "tempfile"

class Vcardfull::Parser::LineReaderTest < Minitest::Test
  def test_each_line_yields_simple_lines
    io = StringIO.new("FN:Alice\nEMAIL:a@b.com\n")

    lines = read_lines(io)

    assert_equal [ "FN:Alice", "EMAIL:a@b.com" ], lines
  end

  def test_each_line_handles_crlf_endings
    io = StringIO.new("FN:Alice\r\nEMAIL:a@b.com\r\n")

    lines = read_lines(io)

    assert_equal [ "FN:Alice", "EMAIL:a@b.com" ], lines
  end

  def test_each_line_handles_cr_only_endings
    io = StringIO.new("FN:Alice\rEMAIL:a@b.com\r")

    lines = read_lines(io)

    assert_equal [ "FN:Alice", "EMAIL:a@b.com" ], lines
  end

  def test_each_line_unfolds_space_continuation
    io = StringIO.new("FN:Alice Very\r\n  Long Name\r\n")

    lines = read_lines(io)

    assert_equal [ "FN:Alice Very Long Name" ], lines
  end

  def test_each_line_unfolds_tab_continuation
    io = StringIO.new("FN:Alice Very\r\n\tLong Name\r\n")

    lines = read_lines(io)

    assert_equal [ "FN:Alice VeryLong Name" ], lines
  end

  def test_each_line_handles_multiple_consecutive_continuations
    io = StringIO.new("FN:A\r\n B\r\n C\r\n D\r\n")

    lines = read_lines(io)

    assert_equal [ "FN:ABCD" ], lines
  end

  def test_each_line_yields_final_line_without_trailing_newline
    io = StringIO.new("FN:Alice")

    lines = read_lines(io)

    assert_equal [ "FN:Alice" ], lines
  end

  def test_each_line_returns_enumerator_without_block
    io = StringIO.new("FN:Alice\n")

    enum = build_reader(io).each_line

    assert_kind_of Enumerator, enum
    assert_equal [ "FN:Alice" ], enum.map(&:read)
  end

  def test_each_line_handles_mixed_continuations_and_regular_lines
    io = StringIO.new("FN:Alice\r\n Long\r\nEMAIL:a@b.com\r\n")

    lines = read_lines(io)

    assert_equal [ "FN:AliceLong", "EMAIL:a@b.com" ], lines
  end

  def test_quoted_printable_aware_joins_soft_line_breaks
    io = StringIO.new("NOTE;ENCODING=QUOTED-PRINTABLE:first=\r\nsecond\r\n")

    lines = read_lines(io, quoted_printable_aware: true)

    assert_equal [ "NOTE;ENCODING=QUOTED-PRINTABLE:firstsecond" ], lines
  end

  def test_quoted_printable_aware_handles_multiple_soft_breaks
    io = StringIO.new("NOTE;ENCODING=QUOTED-PRINTABLE:a=\r\nb=\r\nc\r\n")

    lines = read_lines(io, quoted_printable_aware: true)

    assert_equal [ "NOTE;ENCODING=QUOTED-PRINTABLE:abc" ], lines
  end

  def test_quoted_printable_aware_does_not_join_when_next_line_starts_with_space
    io = StringIO.new("FN;ENCODING=QUOTED-PRINTABLE:Alice=\r\n  Smith\r\n")

    lines = read_lines(io, quoted_printable_aware: true)

    assert_equal [ "FN;ENCODING=QUOTED-PRINTABLE:Alice= Smith" ], lines, "Standard unfolding takes precedence over quoted-printable"
  end

  def test_quoted_printable_aware_does_not_join_non_quoted_printable_lines_ending_with_equals
    io = StringIO.new("PHOTO;ENCODING=BASE64:YmluYXJ5IHBob3RvIGRhdGE=\r\nEND:VCARD\r\n")

    lines = read_lines(io, quoted_printable_aware: true)

    assert_equal [ "PHOTO;ENCODING=BASE64:YmluYXJ5IHBob3RvIGRhdGE=", "END:VCARD" ], lines,
      "Should not join lines ending with = unless ENCODING=QUOTED-PRINTABLE"
  end

  def test_non_quoted_printable_aware_does_not_join_soft_breaks
    io = StringIO.new("NOTE;ENCODING=QUOTED-PRINTABLE:first=\r\nsecond\r\n")

    lines = read_lines(io, quoted_printable_aware: false)

    assert_equal [ "NOTE;ENCODING=QUOTED-PRINTABLE:first=", "second" ], lines
  end

  def test_each_line_yields_io_objects
    io = StringIO.new("FN:Alice\n")

    build_reader(io).each_line do |line_io|
      assert_respond_to line_io, :read, "each_line should yield IO objects"
      assert_equal "FN:Alice", line_io.read
    end
  end

  def test_each_line_streams_large_values_through_buffer_in_chunks
    long_value = "x" * 100
    io = StringIO.new("PHOTO;ENCODING=BASE64:#{long_value}\r\nFN:Alice\r\n")

    lines = Vcardfull::Parser::LineReader.new(io, large_value_threshold: 16).each_line.map(&:read)

    assert_equal [ "PHOTO;ENCODING=BASE64:#{long_value}", "FN:Alice" ], lines,
      "Should correctly reassemble lines longer than the large_value_threshold"
  end

  def test_each_line_promotes_buffer_to_tempfile_for_large_values
    large_value = "x" * 200
    io = StringIO.new("PHOTO:#{large_value}\r\nFN:Alice\r\n")

    yielded_types = []
    Vcardfull::Parser::LineReader.new(io, large_value_threshold: 100).each_line do |line_io|
      yielded_types << line_io.class
      line_io.read
    end

    assert_equal Tempfile, yielded_types[0], "Large value should be yielded as a Tempfile"
    assert_equal StringIO, yielded_types[1], "Small value should remain a StringIO"
  end

  def test_each_line_tempfile_contains_correct_content
    large_value = "y" * 200
    io = StringIO.new("PHOTO:#{large_value}\r\n")

    lines = Vcardfull::Parser::LineReader.new(io, large_value_threshold: 100).each_line.map(&:read)

    assert_equal [ "PHOTO:#{large_value}" ], lines
  end

  def test_each_line_does_not_promote_for_value_at_threshold
    value = "x" * 100
    io = StringIO.new("FN:#{value}\r\n")

    yielded_types = []
    Vcardfull::Parser::LineReader.new(io, large_value_threshold: 100 + 3).each_line do |line_io|
      yielded_types << line_io.class
      line_io.read
    end

    assert_equal StringIO, yielded_types[0], "Value at threshold should not be promoted"
  end

  def test_each_line_does_not_reuse_tempfile_across_lines
    large_value = "x" * 200
    io = StringIO.new("PHOTO:#{large_value}\r\nFN:Alice\r\n")

    yielded_buffers = []
    Vcardfull::Parser::LineReader.new(io, large_value_threshold: 100).each_line do |line_io|
      yielded_buffers << line_io
      line_io.read
    end

    assert_instance_of Tempfile, yielded_buffers[0], "Large value should be a Tempfile"
    assert_instance_of StringIO, yielded_buffers[1], "Small value should be a StringIO"
  end

  private
    def build_reader(io, **options)
      options[:large_value_threshold] ||= Vcardfull::Parser::DEFAULT_LARGE_VALUE_THRESHOLD
      Vcardfull::Parser::LineReader.new(io, **options)
    end

    def read_lines(io, **options)
      build_reader(io, **options).each_line.map(&:read)
    end
end
