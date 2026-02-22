# frozen_string_literal: true

require_relative "../../test_helper"
require "base64"
require "tempfile"

class Vcardfull::Parser::V21Test < Minitest::Test
  def test_parse_handles_bare_type_params
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      UID:abc
      FN:Alice
      TEL;HOME;VOICE;PREF:+1-555-0100
      END:VCARD
    VCF

    assert_equal "home", attrs.phones[0].label
    assert_equal 1, attrs.phones[0].pref
  end

  def test_parse_decodes_quoted_printable_note
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      UID:abc
      FN:Alice
      NOTE;ENCODING=QUOTED-PRINTABLE:=C3=BC=C3=B6=C3=A4
      END:VCARD
    VCF

    assert_equal "üöä", attrs.note
  end

  def test_parse_decodes_quoted_printable_with_soft_line_breaks
    vcf = "BEGIN:VCARD\r\nVERSION:2.1\r\nUID:abc\r\nFN:Alice\r\nNOTE;ENCODING=QUOTED-PRINTABLE:This is a long line that =\r\ncontinues on the next line\r\nEND:VCARD\r\n"
    attrs = parse(vcf)

    assert_equal "This is a long line that continues on the next line", attrs.note
  end

  def test_parse_decodes_quoted_printable_with_multiple_soft_breaks
    vcf = "BEGIN:VCARD\r\nVERSION:2.1\r\nUID:abc\r\nFN:Alice\r\nNOTE;ENCODING=QUOTED-PRINTABLE:first=\r\nsecond=\r\nthird\r\nEND:VCARD\r\n"
    attrs = parse(vcf)

    assert_equal "firstsecondthird", attrs.note
  end

  def test_parse_decodes_base64_photo
    photo_data = "binary photo data"
    encoded = Base64.strict_encode64(photo_data)
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      UID:abc
      FN:Alice
      PHOTO;ENCODING=BASE64:#{encoded}
      END:VCARD
    VCF

    photo = attrs.custom_properties.find { |p| p.name == "PHOTO" }
    assert_equal photo_data, photo.value
  end

  def test_factory_dispatches_to_v21
    attrs = Vcardfull::Parser.parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      UID:abc
      FN:Alice
      TEL;CELL;PREF:+1-555-0100
      END:VCARD
    VCF

    assert_equal "2.1", attrs.version
    assert_equal "cell", attrs.phones[0].label
    assert_equal 1, attrs.phones[0].pref
  end

  def test_charset_param_is_not_leaked_to_custom_properties
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      UID:abc
      FN:Alice
      NOTE;ENCODING=QUOTED-PRINTABLE;CHARSET=UTF-8:Hello
      END:VCARD
    VCF

    assert_equal "Hello", attrs.note
  end

  def test_round_trip_parse_serialize_parse
    original = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      UID:round-trip-21
      FN:Alice Smith
      TEL;HOME;PREF:+1-555-0100
      EMAIL;WORK:alice@work.com
      END:VCARD
    VCF

    vcf = Vcardfull::Serializer::V21.new(original).to_vcf
    reparsed = Vcardfull::Parser.parse(vcf)

    assert_equal "2.1", reparsed.version
    assert_equal "round-trip-21", reparsed.uid
    assert_equal "Alice Smith", reparsed.formatted_name
    assert_equal "+1-555-0100", reparsed.phones[0].number
    assert_equal "home", reparsed.phones[0].label
    assert_equal 1, reparsed.phones[0].pref
    assert_equal "alice@work.com", reparsed.emails[0].address
    assert_equal "work", reparsed.emails[0].label
  end

  def test_does_not_unescape_backslash_sequences
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      UID:abc
      FN:Smith\\, Alice
      END:VCARD
    VCF

    assert_equal "Smith\\, Alice", attrs.formatted_name, "vCard 2.1 should not unescape backslash sequences"
  end

  def test_large_base64_value_stays_as_io_with_encoding_param_preserved
    large_data = "x" * 2_000_000
    encoded = Base64.strict_encode64(large_data)
    vcf = "BEGIN:VCARD\r\nVERSION:2.1\r\nUID:abc\r\nFN:Alice\r\nPHOTO;ENCODING=BASE64:#{encoded}\r\nEND:VCARD\r\n"

    attrs = Vcardfull::Parser::V21.new(vcf, large_value_threshold: 1_000_000).parse

    photo = attrs.custom_properties.find { |p| p.name == "PHOTO" }
    assert_instance_of Tempfile, photo.value, "Large V21 values above threshold should be Tempfiles"
    assert_includes photo.params, "ENCODING=BASE64", "ENCODING param should be preserved for large undecoded values"
  ensure
    photo&.value&.close!
  end

  # ── Spec compliance ──────────────────────────────────────────────────────────
  # The following tests are derived from examples in the official vCard 2.1 spec:
  # https://web.archive.org/web/20120104222727/http://www.imc.org/pdi/vcard-21.txt

  # Section 3.1.1 — Text/Plain MIME basic vCard
  def test_spec_3_1_1_basic_vcard
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Smith;John;M.;Mr.;Esq.
      TEL;WORK;VOICE;MSG:+1 (919) 555-1234
      TEL;WORK;FAX:+1 (919) 555-9876
      ADR;WORK;PARCEL;POSTAL;DOM:Suite 101;1 Central St.;Any Town;NC;27654
      END:VCARD
    VCF

    assert_equal "2.1", attrs.version
    assert_equal "Smith", attrs.family_name
    assert_equal "John", attrs.given_name
    assert_equal "M.", attrs.additional_names
    assert_equal "Mr.", attrs.honorific_prefix
    assert_equal "Esq.", attrs.honorific_suffix

    assert_equal 2, attrs.phones.size
    assert_equal "+1 (919) 555-1234", attrs.phones[0].number
    assert_equal "work", attrs.phones[0].label
    assert_equal "+1 (919) 555-9876", attrs.phones[1].number
    assert_equal "work", attrs.phones[1].label

    assert_equal 1, attrs.addresses.size
    addr = attrs.addresses[0]
    assert_equal "Suite 101", addr.po_box
    assert_equal "1 Central St.", addr.extended
    assert_equal "Any Town", addr.street
    assert_equal "NC", addr.locality
    assert_equal "27654", addr.region
  end

  # Section 3.1.2 — Text/Plain MIME separate vCard
  def test_spec_3_1_2_separate_vcard
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Martin;Stephen
      TEL;HOME;VOICE:+1 (210) 555-1357
      TEL;HOME;FAX:+1 (210) 555-0864
      ADR;WORK;PARCEL;POSTAL;DOM:123 Cliff Ave.;Big Town;CA;97531
      END:VCARD
    VCF

    assert_equal "Martin", attrs.family_name
    assert_equal "Stephen", attrs.given_name

    assert_equal 2, attrs.phones.size
    assert_equal "+1 (210) 555-1357", attrs.phones[0].number
    assert_equal "home", attrs.phones[0].label
    assert_equal "+1 (210) 555-0864", attrs.phones[1].number
    assert_equal "home", attrs.phones[1].label

    assert_equal 1, attrs.addresses.size
    addr = attrs.addresses[0]
    assert_equal "123 Cliff Ave.", addr.po_box
    assert_equal "Big Town", addr.extended
    assert_equal "CA", addr.street
    assert_equal "97531", addr.locality
  end

  # Section 3.1.3 — Application/Directory complete example with CELL and PHOTO
  def test_spec_3_1_3_complete_vcard_with_cell_and_photo
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Smith;John;M.;Mr.;Esq.
      TEL;WORK;VOICE;MSG:+1 (919) 555-1234
      TEL;CELL:+1 (919) 554-6758
      TEL;WORK;FAX:+1 (919) 555-9876
      PHOTO;GIF;MIME:<<JOHNSMITH.part3.960129T083020.xyzMail@host3.com>
      ADR;WORK;PARCEL;POSTAL;DOM:Suite 101;1 Central St.;Any Town;NC;27654
      END:VCARD
    VCF

    assert_equal 3, attrs.phones.size
    assert_equal "+1 (919) 555-1234", attrs.phones[0].number
    assert_equal "work", attrs.phones[0].label
    assert_equal "+1 (919) 554-6758", attrs.phones[1].number
    assert_equal "cell", attrs.phones[1].label
    assert_equal "+1 (919) 555-9876", attrs.phones[2].number
    assert_equal "work", attrs.phones[2].label

    photo = attrs.custom_properties.find { |p| p.name == "PHOTO" }
    refute_nil photo, "PHOTO property should be parsed"
  end

  # Section 2.2.2 — N property with comma in family name
  def test_spec_2_2_2_name_with_comma
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Veni, Vidi, Vici;The Restaurant.
      FN:The Restaurant. Veni, Vidi, Vici
      END:VCARD
    VCF

    assert_equal "Veni, Vidi, Vici", attrs.family_name, "vCard 2.1 should not unescape commas"
    assert_equal "The Restaurant.", attrs.given_name
  end

  # Section 2.2.2 — N property with all five components
  def test_spec_2_2_2_structured_name
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John;Quinlan;Mr.;Esq.
      FN:Mr. John Q. Public, Esq.
      END:VCARD
    VCF

    assert_equal "Public", attrs.family_name
    assert_equal "John", attrs.given_name
    assert_equal "Quinlan", attrs.additional_names
    assert_equal "Mr.", attrs.honorific_prefix
    assert_equal "Esq.", attrs.honorific_suffix
    assert_equal "Mr. John Q. Public, Esq.", attrs.formatted_name
  end

  # Section 2.2.4 — Birthdate property (compact format)
  def test_spec_2_2_4_birthdate_compact
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      BDAY:19950415
      END:VCARD
    VCF

    assert_equal "19950415", attrs.birthday
  end

  # Section 2.2.4 — Birthdate property (dashed format)
  def test_spec_2_2_4_birthdate_dashed
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      BDAY:1995-04-15
      END:VCARD
    VCF

    assert_equal "1995-04-15", attrs.birthday
  end

  # Section 2.3.1 — Delivery address with DOM and HOME types
  def test_spec_2_3_1_address_with_dom_home
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      ADR;DOM;HOME:P.O. Box 101;Suite 101;123 Main Street;Any Town;CA;91921-1234;
      END:VCARD
    VCF

    assert_equal 1, attrs.addresses.size
    addr = attrs.addresses[0]
    assert_equal "P.O. Box 101", addr.po_box
    assert_equal "Suite 101", addr.extended
    assert_equal "123 Main Street", addr.street
    assert_equal "Any Town", addr.locality
    assert_equal "CA", addr.region
    assert_equal "91921-1234", addr.postal_code
  end

  # Section 2.3.1 — Delivery address with multiple types and empty components
  def test_spec_2_3_1_address_with_empty_components
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      ADR;DOM;WORK;HOME;POSTAL:P.O. Box 101;;;Any Town;CA;91921-1234;
      END:VCARD
    VCF

    assert_equal 1, attrs.addresses.size
    addr = attrs.addresses[0]
    assert_equal "P.O. Box 101", addr.po_box
    assert_nil addr.extended
    assert_nil addr.street
    assert_equal "Any Town", addr.locality
    assert_equal "CA", addr.region
    assert_equal "91921-1234", addr.postal_code
  end

  # Section 2.3.2 — Delivery label with quoted-printable encoding
  def test_spec_2_3_2_label_with_quoted_printable
    vcf = "BEGIN:VCARD\r\nVERSION:2.1\r\nN:Public;John\r\nFN:John Public\r\nLABEL;DOM;POSTAL;ENCODING=QUOTED-PRINTABLE:P. O. Box 456=0D=0A=\r\n123 Main Street=0D=0A=\r\nAny Town, CA 91921-1234\r\nEND:VCARD\r\n"
    attrs = parse(vcf)

    label = attrs.custom_properties.find { |p| p.name == "LABEL" }
    refute_nil label, "LABEL property should be parsed"
    assert_equal "P. O. Box 456\r\n123 Main Street\r\nAny Town, CA 91921-1234", label.value
  end

  # Section 2.4.1 — Telephone with PREF, WORK, MSG, FAX bare types
  def test_spec_2_4_1_telephone_with_pref
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      TEL;PREF;WORK;MSG;FAX:+1-800-555-1234
      END:VCARD
    VCF

    assert_equal 1, attrs.phones.size
    assert_equal "+1-800-555-1234", attrs.phones[0].number
    assert_equal 1, attrs.phones[0].pref, "PREF bare param should set pref to 1"
  end

  # Section 2.4.1 — Telephone with WORK, HOME, VOICE, FAX bare types
  def test_spec_2_4_1_telephone_with_multiple_types
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      TEL;WORK;HOME;VOICE;FAX:+1-800-555-1234
      END:VCARD
    VCF

    assert_equal 1, attrs.phones.size
    assert_equal "+1-800-555-1234", attrs.phones[0].number
    assert_equal "work", attrs.phones[0].label
  end

  # Section 2.4.2 — Email with INTERNET type
  def test_spec_2_4_2_email_with_internet_type
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      EMAIL;INTERNET:john.public@abc.com
      END:VCARD
    VCF

    assert_equal 1, attrs.emails.size
    assert_equal "john.public@abc.com", attrs.emails[0].address
    assert_equal "internet", attrs.emails[0].label
  end

  # Section 2.4.3 — Mailer property
  def test_spec_2_4_3_mailer
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      MAILER:ccMail 2.2
      END:VCARD
    VCF

    mailer = attrs.custom_properties.find { |p| p.name == "MAILER" }
    refute_nil mailer, "MAILER property should be parsed"
    assert_equal "ccMail 2.2", mailer.value
  end

  # Section 2.4.5 — Time zone property
  def test_spec_2_4_5_timezone
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      TZ:-05:00
      END:VCARD
    VCF

    tz = attrs.custom_properties.find { |p| p.name == "TZ" }
    refute_nil tz, "TZ property should be parsed"
    assert_equal "-05:00", tz.value
  end

  # Section 2.5.5 — Organization with multiple components
  def test_spec_2_5_5_organization
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      ORG:ABC, Inc.;North American Division;Marketing
      END:VCARD
    VCF

    org = attrs.custom_properties.find { |p| p.name == "ORG" }
    refute_nil org, "ORG property should be parsed"
    assert_equal "ABC, Inc.;North American Division;Marketing", org.value
  end

  # Section 2.6.1 — Note with quoted-printable encoding and soft line breaks
  def test_spec_2_6_1_note_with_quoted_printable
    vcf = "BEGIN:VCARD\r\nVERSION:2.1\r\nN:Public;John\r\nFN:John Public\r\nNOTE;ENCODING=QUOTED-PRINTABLE:This facsimile machine if operational =\r\n0830 to 1715 hours=0D=0A=\r\nMonday through Friday. Call +1-213-555-1234 if you have problems=0D=0A=\r\nwith access to the machine.\r\nEND:VCARD\r\n"
    attrs = parse(vcf)

    expected = "This facsimile machine if operational 0830 to 1715 hours\r\nMonday through Friday. Call +1-213-555-1234 if you have problems\r\nwith access to the machine."
    assert_equal expected, attrs.note
  end

  # Section 2.6.3 — Sound with phonetic spelling
  def test_spec_2_6_3_sound_phonetic
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      SOUND:JON Q PUBLIK
      END:VCARD
    VCF

    sound = attrs.custom_properties.find { |p| p.name == "SOUND" }
    refute_nil sound, "SOUND property should be parsed"
    assert_equal "JON Q PUBLIK", sound.value
  end

  # Section 2.6.3 — Sound with VALUE=URL
  def test_spec_2_6_3_sound_with_value_url
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      SOUND;VALUE=URL:file///multimed/audio/jqpublic.wav
      END:VCARD
    VCF

    sound = attrs.custom_properties.find { |p| p.name == "SOUND" }
    refute_nil sound, "SOUND property should be parsed"
    assert_equal "file///multimed/audio/jqpublic.wav", sound.value
  end

  # Section 2.6.4 — URL property
  def test_spec_2_6_4_url
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      URL:http://abc.com/pub/directory/northam/jpublic.ecd
      END:VCARD
    VCF

    assert_equal 1, attrs.urls.size
    assert_equal "http://abc.com/pub/directory/northam/jpublic.ecd", attrs.urls[0].url
  end

  # Section 2.6.5 — Unique identifier
  def test_spec_2_6_5_unique_identifier
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      UID:19950401-080045-40000F192713-0052
      END:VCARD
    VCF

    assert_equal "19950401-080045-40000F192713-0052", attrs.uid
  end

  # Section 2.8.1 — Extension property (X-ABC-VIDEO)
  def test_spec_2_8_1_extension_property
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      X-ABC-VIDEO;MPEG2:http://lonestar.bubbas.org/billibob.mpg
      END:VCARD
    VCF

    video = attrs.custom_properties.find { |p| p.name == "X-ABC-VIDEO" }
    refute_nil video, "X-ABC-VIDEO extension property should be parsed"
    assert_equal "http://lonestar.bubbas.org/billibob.mpg", video.value
  end

  # Section 2.2.3 — Photo with VALUE=URL
  def test_spec_2_2_3_photo_with_value_url
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      PHOTO;VALUE=URL:file:///jqpublic.gif
      END:VCARD
    VCF

    photo = attrs.custom_properties.find { |p| p.name == "PHOTO" }
    refute_nil photo, "PHOTO property should be parsed"
    assert_equal "file:///jqpublic.gif", photo.value
  end

  # Section 2.2.3 — Photo with BASE64 encoding
  def test_spec_2_2_3_photo_with_base64
    photo_data = "GIF89a binary data here"
    encoded = Base64.strict_encode64(photo_data)

    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      PHOTO;ENCODING=BASE64;TYPE=GIF:#{encoded}
      END:VCARD
    VCF

    photo = attrs.custom_properties.find { |p| p.name == "PHOTO" }
    refute_nil photo, "PHOTO property should be parsed"
    assert_equal photo_data, photo.value
  end

  # Section 2.1.4.2 — Property grouping (A.TEL, A.NOTE)
  # The spec allows grouping properties with a prefix like "A.TEL" and "A.NOTE".
  # This parser does not yet support property grouping — the group prefix is
  # treated as part of the property name, so "A.TEL" is not recognized as "TEL".
  def test_spec_2_1_4_2_property_grouping
    skip "Property grouping (e.g. A.TEL, A.NOTE) is not yet supported"

    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:2.1
      N:Public;John
      FN:John Public
      A.TEL;HOME:+1-213-555-1234
      A.NOTE:This is my vacation home.
      END:VCARD
    VCF

    assert_equal 1, attrs.phones.size, "Grouped TEL property should be parsed"
    assert_equal "+1-213-555-1234", attrs.phones[0].number
    assert_equal "home", attrs.phones[0].label
    assert_equal "This is my vacation home.", attrs.note
  end

  # Combined spec example — all major property types from the spec in one vCard
  def test_spec_combined_all_major_properties
    vcf = "BEGIN:VCARD\r\nVERSION:2.1\r\nN:Public;John;Quinlan;Mr.;Esq.\r\nFN:Mr. John Q. Public, Esq.\r\nORG:ABC, Inc.;North American Division;Marketing\r\nTITLE:Director, Research and Development\r\nTEL;PREF;WORK;VOICE;MSG:+1-800-555-1234\r\nTEL;WORK;FAX:+1-800-555-9876\r\nEMAIL;INTERNET:john.public@abc.com\r\nADR;DOM;HOME:P.O. Box 101;Suite 101;123 Main Street;Any Town;CA;91921-1234;\r\nLABEL;DOM;POSTAL;ENCODING=QUOTED-PRINTABLE:P. O. Box 456=0D=0A=\r\n123 Main Street=0D=0A=\r\nAny Town, CA 91921-1234\r\nNOTE;ENCODING=QUOTED-PRINTABLE:This facsimile machine if operational =\r\n0830 to 1715 hours=0D=0A=\r\nMonday through Friday.\r\nURL:http://abc.com/pub/directory/northam/jpublic.ecd\r\nUID:19950401-080045-40000F192713-0052\r\nEND:VCARD\r\n"
    attrs = parse(vcf)

    assert_equal "2.1", attrs.version
    assert_equal "Public", attrs.family_name
    assert_equal "John", attrs.given_name
    assert_equal "Quinlan", attrs.additional_names
    assert_equal "Mr.", attrs.honorific_prefix
    assert_equal "Esq.", attrs.honorific_suffix
    assert_equal "Mr. John Q. Public, Esq.", attrs.formatted_name
    assert_equal "19950401-080045-40000F192713-0052", attrs.uid

    org = attrs.custom_properties.find { |p| p.name == "ORG" }
    assert_equal "ABC, Inc.;North American Division;Marketing", org.value

    title = attrs.custom_properties.find { |p| p.name == "TITLE" }
    assert_equal "Director, Research and Development", title.value

    assert_equal 2, attrs.phones.size
    assert_equal "+1-800-555-1234", attrs.phones[0].number
    assert_equal 1, attrs.phones[0].pref
    assert_equal "+1-800-555-9876", attrs.phones[1].number

    assert_equal 1, attrs.emails.size
    assert_equal "john.public@abc.com", attrs.emails[0].address

    assert_equal 1, attrs.addresses.size
    addr = attrs.addresses[0]
    assert_equal "P.O. Box 101", addr.po_box
    assert_equal "Suite 101", addr.extended
    assert_equal "123 Main Street", addr.street

    label = attrs.custom_properties.find { |p| p.name == "LABEL" }
    assert_equal "P. O. Box 456\r\n123 Main Street\r\nAny Town, CA 91921-1234", label.value

    expected_note = "This facsimile machine if operational 0830 to 1715 hours\r\nMonday through Friday."
    assert_equal expected_note, attrs.note

    assert_equal 1, attrs.urls.size
    assert_equal "http://abc.com/pub/directory/northam/jpublic.ecd", attrs.urls[0].url
  end

  private
    def parse(vcf_text)
      Vcardfull::Parser::V21.new(vcf_text).parse
    end
end
