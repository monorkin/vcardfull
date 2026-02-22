require_relative "../test_helper"
require "tempfile"

class Vcardfull::ParserTest < Minitest::Test
  def test_parse_extracts_version_and_uid
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc-123
      FN:Alice
      END:VCARD
    VCF

    assert_equal "4.0", attrs.version
    assert_equal "abc-123", attrs.uid
  end

  def test_parse_extracts_formatted_name
    attrs = parse("BEGIN:VCARD\r\nVERSION:4.0\r\nUID:abc\r\nFN:Alice Smith\r\nEND:VCARD\r\n")

    assert_equal "Alice Smith", attrs.formatted_name
  end

  def test_parse_extracts_structured_name_parts
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Dr. Alice B. Smith Jr.
      N:Smith;Alice;B.;Dr.;Jr.
      END:VCARD
    VCF

    assert_equal "Smith", attrs.family_name
    assert_equal "Alice", attrs.given_name
    assert_equal "B.", attrs.additional_names
    assert_equal "Dr.", attrs.honorific_prefix
    assert_equal "Jr.", attrs.honorific_suffix
  end

  def test_parse_extracts_simple_properties
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Alice
      KIND:individual
      NICKNAME:Ali
      BDAY:1990-01-15
      NOTE:A friend
      PRODID:-//Test//Test//EN
      END:VCARD
    VCF

    assert_equal "individual", attrs.kind
    assert_equal "Ali", attrs.nickname
    assert_equal "1990-01-15", attrs.birthday
    assert_equal "A friend", attrs.note
    assert_equal "-//Test//Test//EN", attrs.product_id
  end

  def test_parse_extracts_emails_with_type_and_pref
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Alice
      EMAIL;TYPE=home;PREF=1:alice@home.com
      EMAIL;TYPE=work:alice@work.com
      END:VCARD
    VCF

    assert_equal 2, attrs.emails.size
    assert_equal "alice@home.com", attrs.emails[0].address
    assert_equal "home", attrs.emails[0].label
    assert_equal 1, attrs.emails[0].pref
    assert_equal "alice@work.com", attrs.emails[1].address
    assert_equal "work", attrs.emails[1].label
    assert_nil attrs.emails[1].pref
  end

  def test_parse_extracts_phone_numbers
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Alice
      TEL;TYPE=cell;PREF=1:+1-555-0100
      END:VCARD
    VCF

    assert_equal 1, attrs.phones.size
    assert_equal "+1-555-0100", attrs.phones[0].number
    assert_equal "cell", attrs.phones[0].label
    assert_equal 1, attrs.phones[0].pref
  end

  def test_parse_extracts_addresses
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Alice
      ADR;TYPE=home;PREF=1:;;123 Main St;Springfield;IL;62701;US
      END:VCARD
    VCF

    assert_equal 1, attrs.addresses.size
    addr = attrs.addresses[0]
    assert_equal "123 Main St", addr.street
    assert_equal "Springfield", addr.locality
    assert_equal "IL", addr.region
    assert_equal "62701", addr.postal_code
    assert_equal "US", addr.country
    assert_equal "home", addr.label
    assert_equal 1, addr.pref
  end

  def test_parse_extracts_urls
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Alice
      URL;TYPE=home:https://example.com
      END:VCARD
    VCF

    assert_equal 1, attrs.urls.size
    assert_equal "https://example.com", attrs.urls[0].url
  end

  def test_parse_extracts_instant_messages
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Alice
      IMPP;TYPE=home:xmpp:alice@example.com
      END:VCARD
    VCF

    assert_equal 1, attrs.instant_messages.size
    assert_equal "xmpp:alice@example.com", attrs.instant_messages[0].uri
  end

  def test_parse_stores_unknown_properties_as_custom_properties
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Alice
      ORG:Acme Corp
      X-CUSTOM;TYPE=work:some value
      END:VCARD
    VCF

    assert_equal 2, attrs.custom_properties.size
    org = attrs.custom_properties.find { |p| p.name == "ORG" }
    assert_equal "Acme Corp", org.value

    custom = attrs.custom_properties.find { |p| p.name == "X-CUSTOM" }
    assert_equal "some value", custom.value
    assert_equal "TYPE=work", custom.params
  end

  def test_parse_handles_line_unfolding
    vcf = "BEGIN:VCARD\r\nVERSION:4.0\r\nUID:abc\r\nFN:Alice Very Long\r\n  Name\r\nEND:VCARD\r\n"
    attrs = parse(vcf)

    assert_equal "Alice Very Long Name", attrs.formatted_name
  end

  def test_parse_handles_crlf_and_lf_line_endings
    crlf = "BEGIN:VCARD\r\nVERSION:4.0\r\nUID:abc\r\nFN:Alice\r\nEND:VCARD\r\n"
    lf = "BEGIN:VCARD\nVERSION:4.0\nUID:abc\nFN:Alice\nEND:VCARD\n"

    assert_equal parse(crlf).formatted_name, parse(lf).formatted_name
  end

  def test_parse_round_trips_through_serializer
    original = Vcardfull::VCard.new(
      version: "4.0",
      uid: "round-trip-test",
      formatted_name: "Alice Smith",
      family_name: "Smith",
      given_name: "Alice",
      nickname: "Ali",
      birthday: "1990-01-15",
      emails: [ { address: "alice@example.com", label: "home", pref: 1, position: 0 } ],
      phones: [ { number: "+1-555-0100", label: "cell", pref: 1, position: 0 } ]
    )

    vcf = Vcardfull::Serializer.new(original).to_vcf
    parsed = Vcardfull::Parser.new(vcf).parse

    assert_equal "4.0", parsed.version
    assert_equal "round-trip-test", parsed.uid
    assert_equal "Alice Smith", parsed.formatted_name
    assert_equal "Smith", parsed.family_name
    assert_equal "Alice", parsed.given_name
    assert_equal "Ali", parsed.nickname
    assert_equal "1990-01-15", parsed.birthday
    assert_equal "alice@example.com", parsed.emails[0].address
    assert_equal "+1-555-0100", parsed.phones[0].number
  end

  def test_parse_unescapes_special_characters
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Smith\\, Alice
      NOTE:Line1\\nLine2
      END:VCARD
    VCF

    assert_equal "Smith, Alice", attrs.formatted_name
    assert_equal "Line1\nLine2", attrs.note
  end

  def test_parse_accepts_io_input
    vcf = "BEGIN:VCARD\r\nVERSION:4.0\r\nUID:abc\r\nFN:Alice Smith\r\nEND:VCARD\r\n"

    attrs = parse_streaming(vcf)

    assert_equal "Alice Smith", attrs.formatted_name
  end

  def test_parse_streaming_handles_line_unfolding
    vcf = "BEGIN:VCARD\r\nVERSION:4.0\r\nUID:abc\r\nFN:Alice Very Long\r\n  Name\r\nEND:VCARD\r\n"

    attrs = parse_streaming(vcf)

    assert_equal "Alice Very Long Name", attrs.formatted_name
  end

  def test_parse_streaming_round_trips_through_serializer
    original = Vcardfull::VCard.new(
      version: "4.0",
      uid: "stream-test",
      formatted_name: "Alice Smith",
      family_name: "Smith",
      given_name: "Alice",
      emails: [ { address: "alice@example.com", label: "home", pref: 1, position: 0 } ]
    )

    vcf = Vcardfull::Serializer.new(original).to_vcf
    parsed = parse_streaming(vcf)

    assert_equal "Alice Smith", parsed.formatted_name
    assert_equal "alice@example.com", parsed.emails[0].address
  end

  def test_parse_stores_small_custom_value_as_string
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Alice
      X-SMALL:tiny value
      END:VCARD
    VCF

    custom = attrs.custom_properties.find { |p| p.name == "X-SMALL" }
    assert_instance_of String, custom.value, "Small custom property values should be stored as strings"
    assert_equal "tiny value", custom.value
  end

  def test_parse_streams_large_custom_value_to_tempfile
    large_value = "x" * 2_000_000
    vcf = "BEGIN:VCARD\r\nVERSION:4.0\r\nUID:abc\r\nFN:Alice\r\nX-LARGE:#{large_value}\r\nEND:VCARD\r\n"

    attrs = Vcardfull::Parser.new(vcf, large_value_threshold: 1_000_000).parse

    custom = attrs.custom_properties.find { |p| p.name == "X-LARGE" }
    assert_instance_of Tempfile, custom.value, "Large custom property values should be stored as Tempfiles"
    assert_equal large_value, custom.value.read
  ensure
    custom&.value&.close!
  end

  def test_parse_does_not_buffer_large_value_in_memory
    large_value = "x" * 200
    vcf = "BEGIN:VCARD\r\nVERSION:4.0\r\nUID:abc\r\nFN:Alice\r\nX-LARGE:#{large_value}\r\nEND:VCARD\r\n"

    attrs = Vcardfull::Parser.new(vcf, large_value_threshold: 100).parse

    custom = attrs.custom_properties.find { |p| p.name == "X-LARGE" }
    assert_instance_of Tempfile, custom.value, "Large values should be stored as Tempfiles"
    assert_equal large_value, custom.value.read
  ensure
    custom&.value&.close! if custom&.value.is_a?(Tempfile)
  end

  def test_parse_configurable_large_value_threshold
    value = "x" * 100
    vcf = "BEGIN:VCARD\r\nVERSION:4.0\r\nUID:abc\r\nFN:Alice\r\nX-DATA:#{value}\r\nEND:VCARD\r\n"

    attrs = Vcardfull::Parser.new(vcf, large_value_threshold: 50).parse

    custom = attrs.custom_properties.find { |p| p.name == "X-DATA" }
    assert_instance_of Tempfile, custom.value, "Values above the configured threshold should be Tempfiles"
    assert_equal value, custom.value.read
  ensure
    custom&.value&.close!
  end

  private
    def parse(vcf_text)
      Vcardfull::Parser.new(vcf_text).parse
    end

    def parse_streaming(vcf_text)
      Vcardfull::Parser.new(StringIO.new(vcf_text)).parse
    end
end
