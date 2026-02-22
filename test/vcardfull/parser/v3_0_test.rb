require_relative "../../test_helper"

class Vcardfull::Parser::V30Test < Minitest::Test
  def test_parse_handles_bare_type_params
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      UID:abc
      FN:Alice
      TEL;CELL:+1-555-0100
      END:VCARD
    VCF

    assert_equal "cell", attrs.phones[0].label
  end

  def test_parse_handles_bare_pref_param
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      UID:abc
      FN:Alice
      TEL;CELL;PREF:+1-555-0100
      END:VCARD
    VCF

    assert_equal "cell", attrs.phones[0].label
    assert_equal 1, attrs.phones[0].pref
  end

  def test_parse_handles_multiple_bare_type_values
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      UID:abc
      FN:Alice
      TEL;HOME;VOICE:+1-555-0100
      END:VCARD
    VCF

    assert_equal "home", attrs.phones[0].label
  end

  def test_parse_handles_mixed_bare_and_keyed_params
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      UID:abc
      FN:Alice
      EMAIL;TYPE=work;PREF:alice@work.com
      END:VCARD
    VCF

    assert_equal "work", attrs.emails[0].label
    assert_equal 1, attrs.emails[0].pref
  end

  def test_factory_dispatches_to_v3
    attrs = Vcardfull::Parser.parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      UID:abc
      FN:Alice
      TEL;CELL;PREF:+1-555-0100
      END:VCARD
    VCF

    assert_equal "3.0", attrs.version
    assert_equal "cell", attrs.phones[0].label
    assert_equal 1, attrs.phones[0].pref
  end

  def test_parse_filters_pref_from_type_values
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      UID:abc
      FN:Alice
      TEL;TYPE=CELL,PREF:+1-555-0100
      END:VCARD
    VCF

    assert_equal "cell", attrs.phones[0].label, "Should filter PREF from TYPE values"
    assert_equal 1, attrs.phones[0].pref, "Should detect PREF in TYPE values"
  end

  # ── Spec compliance ──────────────────────────────────────────────────────────
  # The following tests are derived from examples in RFC 2426 (vCard 3.0):
  # https://datatracker.ietf.org/doc/html/rfc2426

  # Section 7 — Author vCard: Frank Dawson
  def test_spec_section_7_frank_dawson
    vcf = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Frank Dawson\r\nORG:Lotus Development Corporation\r\nADR;TYPE=WORK,POSTAL,PARCEL:;;6544 Battleford Drive\r\n ;Raleigh;NC;27613-3502;U.S.A.\r\nTEL;TYPE=VOICE,MSG,WORK:+1-919-676-9515\r\nTEL;TYPE=FAX,WORK:+1-919-676-9564\r\nEMAIL;TYPE=INTERNET,PREF:Frank_Dawson@Lotus.com\r\nEMAIL;TYPE=INTERNET:fdawson@earthlink.net\r\nURL:http://home.earthlink.net/~fdawson\r\nEND:VCARD\r\n"
    attrs = parse(vcf)

    assert_equal "3.0", attrs.version
    assert_equal "Frank Dawson", attrs.formatted_name

    org = attrs.custom_properties.find { |p| p.name == "ORG" }
    assert_equal "Lotus Development Corporation", org.value

    assert_equal 1, attrs.addresses.size
    addr = attrs.addresses[0]
    assert_equal "6544 Battleford Drive", addr.street
    assert_equal "Raleigh", addr.locality
    assert_equal "NC", addr.region
    assert_equal "27613-3502", addr.postal_code
    assert_equal "U.S.A.", addr.country

    assert_equal 2, attrs.phones.size
    assert_equal "+1-919-676-9515", attrs.phones[0].number
    assert_equal "voice", attrs.phones[0].label
    assert_equal "+1-919-676-9564", attrs.phones[1].number
    assert_equal "fax", attrs.phones[1].label

    assert_equal 2, attrs.emails.size
    assert_equal "Frank_Dawson@Lotus.com", attrs.emails[0].address
    assert_equal 1, attrs.emails[0].pref, "PREF in TYPE list should set pref to 1"
    assert_equal "fdawson@earthlink.net", attrs.emails[1].address

    assert_equal 1, attrs.urls.size
    assert_equal "http://home.earthlink.net/~fdawson", attrs.urls[0].url
  end

  # Section 7 — Author vCard: Tim Howes
  def test_spec_section_7_tim_howes
    vcf = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Tim Howes\r\nORG:Netscape Communications Corp.\r\nADR;TYPE=WORK:;;501 E. Middlefield Rd.;Mountain View;\r\n CA; 94043;U.S.A.\r\nTEL;TYPE=VOICE,MSG,WORK:+1-415-937-3419\r\nTEL;TYPE=FAX,WORK:+1-415-528-4164\r\nEMAIL;TYPE=INTERNET:howes@netscape.com\r\nEND:VCARD\r\n"
    attrs = parse(vcf)

    assert_equal "Tim Howes", attrs.formatted_name

    org = attrs.custom_properties.find { |p| p.name == "ORG" }
    assert_equal "Netscape Communications Corp.", org.value

    assert_equal 1, attrs.addresses.size
    addr = attrs.addresses[0]
    assert_equal "501 E. Middlefield Rd.", addr.street
    assert_equal "Mountain View", addr.locality

    assert_equal 2, attrs.phones.size
    assert_equal "+1-415-937-3419", attrs.phones[0].number
    assert_equal "+1-415-528-4164", attrs.phones[1].number

    assert_equal 1, attrs.emails.size
    assert_equal "howes@netscape.com", attrs.emails[0].address
  end

  # Section 3.1.1 — FN with escaped comma
  def test_spec_3_1_1_formatted_name_with_escaped_comma
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:Mr. John Q. Public\\, Esq.
      N:Public;John;Quinlan;Mr.;Esq.
      END:VCARD
    VCF

    assert_equal "Mr. John Q. Public, Esq.", attrs.formatted_name
  end

  # Section 3.1.2 — N with multiple additional names
  def test_spec_3_1_2_structured_name_with_multiple_additional_names
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:Dr. John Philip Paul Stevenson Jr., M.D., A.C.P.
      N:Stevenson;John;Philip,Paul;Dr.;Jr.,M.D.,A.C.P.
      END:VCARD
    VCF

    assert_equal "Stevenson", attrs.family_name
    assert_equal "John", attrs.given_name
    assert_equal "Philip,Paul", attrs.additional_names
    assert_equal "Dr.", attrs.honorific_prefix
    assert_equal "Jr.,M.D.,A.C.P.", attrs.honorific_suffix
  end

  # Section 3.1.3 — NICKNAME
  def test_spec_3_1_3_nickname
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:Robbie
      N:;Robbie
      NICKNAME:Robbie
      END:VCARD
    VCF

    assert_equal "Robbie", attrs.nickname
  end

  # Section 3.1.4 — PHOTO with VALUE=uri
  def test_spec_3_1_4_photo_with_uri
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      PHOTO;VALUE=uri:http://www.abc.com/pub/photos/jqpublic.gif
      END:VCARD
    VCF

    photo = attrs.custom_properties.find { |p| p.name == "PHOTO" }
    refute_nil photo, "PHOTO property should be parsed"
    assert_equal "http://www.abc.com/pub/photos/jqpublic.gif", photo.value
  end

  # Section 3.1.5 — BDAY
  def test_spec_3_1_5_birthday
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      BDAY:1996-04-15
      END:VCARD
    VCF

    assert_equal "1996-04-15", attrs.birthday
  end

  def test_spec_3_1_5_birthday_with_timestamp
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      BDAY:1953-10-15T23:10:00Z
      END:VCARD
    VCF

    assert_equal "1953-10-15T23:10:00Z", attrs.birthday
  end

  # Section 3.2.1 — ADR with TYPE list
  def test_spec_3_2_1_address_with_type_list
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      ADR;TYPE=dom,home,postal,parcel:;;123 Main Street;Any Town;CA;91921-1234
      END:VCARD
    VCF

    assert_equal 1, attrs.addresses.size
    addr = attrs.addresses[0]
    assert_equal "dom", addr.label
    assert_equal "123 Main Street", addr.street
    assert_equal "Any Town", addr.locality
    assert_equal "CA", addr.region
    assert_equal "91921-1234", addr.postal_code
  end

  # Section 3.3.1 — TEL with TYPE list including pref
  def test_spec_3_3_1_telephone_with_pref_in_type_list
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      TEL;TYPE=work,voice,pref,msg:+1-213-555-1234
      END:VCARD
    VCF

    assert_equal 1, attrs.phones.size
    assert_equal "+1-213-555-1234", attrs.phones[0].number
    assert_equal "work", attrs.phones[0].label
    assert_equal 1, attrs.phones[0].pref, "PREF in TYPE list should set pref to 1"
  end

  # Section 3.3.2 — EMAIL with TYPE=internet,pref
  def test_spec_3_3_2_email_with_pref_in_type
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:Jane Doe
      N:Doe;Jane
      EMAIL;TYPE=internet,pref:jane_doe@abc.com
      END:VCARD
    VCF

    assert_equal 1, attrs.emails.size
    assert_equal "jane_doe@abc.com", attrs.emails[0].address
    assert_equal 1, attrs.emails[0].pref
  end

  # Section 3.3.3 — MAILER
  def test_spec_3_3_3_mailer
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      MAILER:PigeonMail 2.1
      END:VCARD
    VCF

    mailer = attrs.custom_properties.find { |p| p.name == "MAILER" }
    refute_nil mailer, "MAILER property should be parsed"
    assert_equal "PigeonMail 2.1", mailer.value
  end

  # Section 3.4.1 — TZ
  def test_spec_3_4_1_timezone
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      TZ:-05:00
      END:VCARD
    VCF

    tz = attrs.custom_properties.find { |p| p.name == "TZ" }
    refute_nil tz, "TZ property should be parsed"
    assert_equal "-05:00", tz.value
  end

  # Section 3.4.2 — GEO
  def test_spec_3_4_2_geo
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      GEO:37.386013;-122.082932
      END:VCARD
    VCF

    geo = attrs.custom_properties.find { |p| p.name == "GEO" }
    refute_nil geo, "GEO property should be parsed"
    assert_equal "37.386013;-122.082932", geo.value
  end

  # Section 3.5.1 — TITLE with escaped comma
  def test_spec_3_5_1_title
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      TITLE:Director\\, Research and Development
      END:VCARD
    VCF

    title = attrs.custom_properties.find { |p| p.name == "TITLE" }
    refute_nil title, "TITLE property should be parsed"
    assert_equal "Director, Research and Development", title.value
  end

  # Section 3.5.2 — ROLE
  def test_spec_3_5_2_role
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      ROLE:Programmer
      END:VCARD
    VCF

    role = attrs.custom_properties.find { |p| p.name == "ROLE" }
    refute_nil role, "ROLE property should be parsed"
    assert_equal "Programmer", role.value
  end

  # Section 3.5.5 — ORG with escaped comma and multiple components
  def test_spec_3_5_5_organization
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      ORG:ABC\\, Inc.;North American Division;Marketing
      END:VCARD
    VCF

    org = attrs.custom_properties.find { |p| p.name == "ORG" }
    refute_nil org, "ORG property should be parsed"
    assert_equal "ABC, Inc.;North American Division;Marketing", org.value
  end

  # Section 3.6.1 — CATEGORIES
  def test_spec_3_6_1_categories_single
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      CATEGORIES:TRAVEL AGENT
      END:VCARD
    VCF

    categories = attrs.custom_properties.find { |p| p.name == "CATEGORIES" }
    refute_nil categories, "CATEGORIES property should be parsed"
    assert_equal "TRAVEL AGENT", categories.value
  end

  def test_spec_3_6_1_categories_multiple
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      CATEGORIES:INTERNET,IETF,INDUSTRY,INFORMATION TECHNOLOGY
      END:VCARD
    VCF

    categories = attrs.custom_properties.find { |p| p.name == "CATEGORIES" }
    refute_nil categories, "CATEGORIES property should be parsed"
    assert_equal "INTERNET,IETF,INDUSTRY,INFORMATION TECHNOLOGY", categories.value
  end

  # Section 3.6.2 — NOTE with escaped characters
  def test_spec_3_6_2_note_with_escaped_comma
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      NOTE:This fax number is operational 0800 to 1715 EST\\, Mon-Fri.
      END:VCARD
    VCF

    assert_equal "This fax number is operational 0800 to 1715 EST, Mon-Fri.", attrs.note
  end

  # Section 3.6.3 — PRODID
  def test_spec_3_6_3_prodid
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      PRODID:-//ONLINE DIRECTORY//NONSGML Version 1//EN
      END:VCARD
    VCF

    assert_equal "-//ONLINE DIRECTORY//NONSGML Version 1//EN", attrs.product_id
  end

  # Section 3.6.4 — REV
  def test_spec_3_6_4_revision
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      REV:1995-10-31T22:27:10Z
      END:VCARD
    VCF

    rev = attrs.custom_properties.find { |p| p.name == "REV" }
    refute_nil rev, "REV property should be parsed"
    assert_equal "1995-10-31T22:27:10Z", rev.value
  end

  # Section 3.6.7 — UID
  def test_spec_3_6_7_uid
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      UID:19950401-080045-40000F192713-0052
      END:VCARD
    VCF

    assert_equal "19950401-080045-40000F192713-0052", attrs.uid
  end

  # Section 3.6.8 — URL
  def test_spec_3_6_8_url
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      URL:http://www.swbyps.restaurant.french/~chezchic.html
      END:VCARD
    VCF

    assert_equal 1, attrs.urls.size
    assert_equal "http://www.swbyps.restaurant.french/~chezchic.html", attrs.urls[0].url
  end

  # Section 3.7.1 — CLASS
  def test_spec_3_7_1_class
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:3.0
      FN:John Public
      N:Public;John
      CLASS:PUBLIC
      END:VCARD
    VCF

    klass = attrs.custom_properties.find { |p| p.name == "CLASS" }
    refute_nil klass, "CLASS property should be parsed"
    assert_equal "PUBLIC", klass.value
  end

  private
    def parse(vcf_text)
      Vcardfull::Parser::V30.new(vcf_text).parse
    end
end
