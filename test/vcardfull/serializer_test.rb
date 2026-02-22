# frozen_string_literal: true

require_relative "../test_helper"

class Vcardfull::SerializerTest < Minitest::Test
  def test_to_vcf_produces_valid_vcard_with_begin_and_end
    vcf = serialize(uid: "abc-123", formatted_name: "Alice")

    assert vcf.start_with?("BEGIN:VCARD\r\n")
    assert vcf.end_with?("END:VCARD\r\n")
  end

  def test_to_vcf_includes_uid_and_fn
    vcf = serialize(uid: "abc-123", formatted_name: "Alice Smith")

    assert_includes vcf, "UID:abc-123\r\n"
    assert_includes vcf, "FN:Alice Smith\r\n"
  end

  def test_to_vcf_includes_structured_name
    vcf = serialize(
      uid: "abc",
      formatted_name: "Dr. Alice B. Smith Jr.",
      family_name: "Smith",
      given_name: "Alice",
      additional_names: "B.",
      honorific_prefix: "Dr.",
      honorific_suffix: "Jr."
    )

    assert_includes vcf, "N:Smith;Alice;B.;Dr.;Jr.\r\n"
  end

  def test_to_vcf_omits_n_line_when_no_name_parts
    vcf = serialize(uid: "abc", formatted_name: "Alice")

    refute_includes vcf, "\r\nN:"
  end

  def test_to_vcf_includes_simple_properties
    vcf = serialize(
      uid: "abc",
      formatted_name: "Alice",
      nickname: "Ali",
      birthday: "1990-01-15",
      note: "A friend"
    )

    assert_includes vcf, "NICKNAME:Ali\r\n"
    assert_includes vcf, "BDAY:1990-01-15\r\n"
    assert_includes vcf, "NOTE:A friend\r\n"
  end

  def test_to_vcf_serializes_emails_with_type_and_pref
    vcf = serialize(
      uid: "abc",
      formatted_name: "Alice",
      emails: [
        { address: "alice@example.com", label: "home", pref: 1 },
        { address: "alice@work.com", label: "work", pref: nil }
      ]
    )

    assert_includes vcf, "EMAIL;TYPE=home;PREF=1:alice@example.com\r\n"
    assert_includes vcf, "EMAIL;TYPE=work:alice@work.com\r\n"
  end

  def test_to_vcf_serializes_phone_numbers
    vcf = serialize(
      uid: "abc",
      formatted_name: "Alice",
      phones: [ { number: "+1-555-0100", label: "cell", pref: 1 } ]
    )

    assert_includes vcf, "TEL;TYPE=cell;PREF=1:+1-555-0100\r\n"
  end

  def test_to_vcf_serializes_addresses
    vcf = serialize(
      uid: "abc",
      formatted_name: "Alice",
      addresses: [ {
        po_box: nil, extended: nil, street: "123 Main St",
        locality: "Springfield", region: "IL", postal_code: "62701", country: "US",
        label: "home", pref: 1
      } ]
    )

    assert_includes vcf, "ADR;TYPE=home;PREF=1:;;123 Main St;Springfield;IL;62701;US\r\n"
  end

  def test_to_vcf_serializes_urls
    vcf = serialize(
      uid: "abc",
      formatted_name: "Alice",
      urls: [ { url: "https://example.com", label: "home", pref: 1 } ]
    )

    assert_includes vcf, "URL;TYPE=home;PREF=1:https://example.com\r\n"
  end

  def test_to_vcf_serializes_instant_messages
    vcf = serialize(
      uid: "abc",
      formatted_name: "Alice",
      instant_messages: [ { uri: "xmpp:alice@example.com", label: "home", pref: 1 } ]
    )

    assert_includes vcf, "IMPP;TYPE=home;PREF=1:xmpp:alice@example.com\r\n"
  end

  def test_to_vcf_serializes_custom_properties
    vcf = serialize(
      uid: "abc",
      formatted_name: "Alice",
      custom_properties: [
        { name: "ORG", value: "Acme Corp", params: nil },
        { name: "X-CUSTOM", value: "value", params: "TYPE=work" }
      ]
    )

    assert_includes vcf, "ORG:Acme Corp\r\n"
    assert_includes vcf, "X-CUSTOM;TYPE=work:value\r\n"
  end

  def test_to_vcf_escapes_commas_and_newlines
    vcf = serialize(
      uid: "abc",
      formatted_name: "Smith, Alice",
      note: "Line1\nLine2"
    )

    assert_includes vcf, "FN:Smith\\, Alice\r\n"
    assert_includes vcf, "NOTE:Line1\\nLine2\r\n"
  end

  def test_to_vcf_serializes_custom_properties_with_io_backed_values
    io_value = StringIO.new("large binary data")
    vcf = serialize(
      uid: "abc",
      formatted_name: "Alice",
      custom_properties: [
        { name: "X-DATA", value: io_value, params: "ENCODING=BASE64" }
      ]
    )

    assert_includes vcf, "X-DATA;ENCODING=BASE64:large binary data\r\n"
  end

  private
    def serialize(attributes)
      Vcardfull::Serializer.new(Vcardfull::VCard.new(**attributes)).to_vcf
    end
end
