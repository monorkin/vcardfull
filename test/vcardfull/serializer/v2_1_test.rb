# frozen_string_literal: true

require_relative "../../test_helper"

class Vcardfull::Serializer::V21Test < Minitest::Test
  def test_to_vcf_outputs_version_2_1
    vcf = serialize(uid: "abc", formatted_name: "Alice")

    assert_includes vcf, "VERSION:2.1\r\n"
  end

  def test_to_vcf_uses_bare_type_params
    vcf = serialize(
      uid: "abc",
      formatted_name: "Alice",
      phones: [ { number: "+1-555-0100", label: "home", pref: nil } ]
    )

    assert_includes vcf, "TEL;HOME:+1-555-0100\r\n"
  end

  def test_to_vcf_uses_bare_pref_param
    vcf = serialize(
      uid: "abc",
      formatted_name: "Alice",
      phones: [ { number: "+1-555-0100", label: "cell", pref: 1 } ]
    )

    assert_includes vcf, "TEL;CELL;PREF:+1-555-0100\r\n"
  end

  def test_to_vcf_quoted_printable_encodes_non_ascii_note
    vcf = serialize(
      uid: "abc",
      formatted_name: "Alice",
      note: "über cool"
    )

    assert_includes vcf, "NOTE;ENCODING=QUOTED-PRINTABLE;CHARSET=UTF-8:"
    refute_includes vcf, "NOTE:über"
  end

  def test_to_vcf_quoted_printable_encodes_non_ascii_fn
    vcf = serialize(
      uid: "abc",
      formatted_name: "Ünsal"
    )

    assert_includes vcf, "FN;ENCODING=QUOTED-PRINTABLE;CHARSET=UTF-8:"
    refute_includes vcf, "FN:Ünsal"
  end

  def test_to_vcf_does_not_escape_commas
    vcf = serialize(
      uid: "abc",
      formatted_name: "Smith, Alice"
    )

    assert_includes vcf, "FN:Smith, Alice\r\n"
    refute_includes vcf, "\\,"
  end

  def test_to_vcf_round_trip_with_parser
    original = Vcardfull::VCard.new(
      version: "2.1",
      uid: "rt-21",
      formatted_name: "Alice Smith",
      family_name: "Smith",
      given_name: "Alice",
      emails: [ { address: "alice@example.com", label: "home", pref: 1, position: 0 } ],
      phones: [ { number: "+1-555-0100", label: "cell", pref: 1, position: 0 } ]
    )

    vcf = Vcardfull::Serializer::V21.new(original).to_vcf
    parsed = Vcardfull::Parser.parse(vcf)

    assert_equal "2.1", parsed.version
    assert_equal "rt-21", parsed.uid
    assert_equal "Alice Smith", parsed.formatted_name
    assert_equal "Smith", parsed.family_name
    assert_equal "Alice", parsed.given_name
    assert_equal "alice@example.com", parsed.emails[0].address
    assert_equal "home", parsed.emails[0].label
    assert_equal 1, parsed.emails[0].pref
    assert_equal "+1-555-0100", parsed.phones[0].number
  end

  def test_to_vcf_round_trip_with_non_ascii
    original = Vcardfull::VCard.new(
      version: "2.1",
      uid: "rt-unicode",
      formatted_name: "Ünsal Özdemir",
      family_name: "Özdemir",
      given_name: "Ünsal",
      note: "Grüße aus München"
    )

    vcf = Vcardfull::Serializer::V21.new(original).to_vcf
    parsed = Vcardfull::Parser.parse(vcf)

    assert_equal "Ünsal Özdemir", parsed.formatted_name
    assert_equal "Grüße aus München", parsed.note
    assert_equal "Özdemir", parsed.family_name
    assert_equal "Ünsal", parsed.given_name
  end

  private
    def serialize(attributes)
      attributes[:version] ||= "2.1"
      Vcardfull::Serializer::V21.new(Vcardfull::VCard.new(**attributes)).to_vcf
    end
end
