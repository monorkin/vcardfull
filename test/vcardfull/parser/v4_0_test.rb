require_relative "../../test_helper"

class Vcardfull::Parser::V40Test < Minitest::Test
  def test_factory_dispatches_to_v4_by_default
    attrs = Vcardfull::Parser.parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Alice
      EMAIL;TYPE=home;PREF=1:alice@home.com
      END:VCARD
    VCF

    assert_equal "4.0", attrs.version
    assert_equal 1, attrs.emails[0].pref
  end

  def test_factory_defaults_to_v4_when_no_version
    attrs = Vcardfull::Parser.parse(<<~VCF)
      BEGIN:VCARD
      UID:abc
      FN:Alice
      END:VCARD
    VCF

    assert_equal "Alice", attrs.formatted_name
  end

  def test_pref_is_integer_value
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Alice
      EMAIL;TYPE=home;PREF=2:alice@home.com
      END:VCARD
    VCF

    assert_equal 2, attrs.emails[0].pref
  end

  def test_factory_accepts_io_input
    io = StringIO.new(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      UID:abc
      FN:Alice
      END:VCARD
    VCF

    attrs = Vcardfull::Parser.parse(io)

    assert_equal "Alice", attrs.formatted_name
  end

  # ── Spec compliance ──────────────────────────────────────────────────────────
  # The following tests are derived from examples in RFC 6350 (vCard 4.0):
  # https://datatracker.ietf.org/doc/html/rfc6350

  # Section 6.1.4 — KIND:individual with ORG
  def test_spec_6_1_4_kind_individual
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      KIND:individual
      FN:Jane Doe
      ORG:ABC\\, Inc.;North American Division;Marketing
      END:VCARD
    VCF

    assert_equal "4.0", attrs.version
    assert_equal "individual", attrs.kind
    assert_equal "Jane Doe", attrs.formatted_name

    org = attrs.custom_properties.find { |p| p.name == "ORG" }
    refute_nil org, "ORG property should be parsed"
    assert_equal "ABC, Inc.;North American Division;Marketing", org.value
  end

  # Section 6.1.4 — KIND:org
  def test_spec_6_1_4_kind_org
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      KIND:org
      FN:ABC Marketing
      ORG:ABC\\, Inc.;North American Division;Marketing
      END:VCARD
    VCF

    assert_equal "org", attrs.kind
    assert_equal "ABC Marketing", attrs.formatted_name
  end

  # Section 6.6.5 — KIND:group with MEMBER properties
  def test_spec_6_6_5_kind_group_with_members
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      KIND:group
      FN:The Doe family
      MEMBER:urn:uuid:03a0e51f-d1aa-4385-8a53-e29025acd8af
      MEMBER:urn:uuid:b8767877-b4a1-4c70-9acc-505d3819e519
      END:VCARD
    VCF

    assert_equal "group", attrs.kind
    assert_equal "The Doe family", attrs.formatted_name

    members = attrs.custom_properties.select { |p| p.name == "MEMBER" }
    assert_equal 2, members.size
    assert_equal "urn:uuid:03a0e51f-d1aa-4385-8a53-e29025acd8af", members[0].value
    assert_equal "urn:uuid:b8767877-b4a1-4c70-9acc-505d3819e519", members[1].value
  end

  # Section 6.6.5 — Distribution list with various MEMBER URIs
  def test_spec_6_6_5_distribution_list
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      KIND:group
      FN:Funky distribution list
      MEMBER:mailto:subscriber1@example.com
      MEMBER:xmpp:subscriber2@example.com
      MEMBER:sip:subscriber3@example.com
      MEMBER:tel:+1-418-555-5555
      END:VCARD
    VCF

    members = attrs.custom_properties.select { |p| p.name == "MEMBER" }
    assert_equal 4, members.size
    assert_equal "mailto:subscriber1@example.com", members[0].value
    assert_equal "xmpp:subscriber2@example.com", members[1].value
    assert_equal "sip:subscriber3@example.com", members[2].value
    assert_equal "tel:+1-418-555-5555", members[3].value
  end

  # Section 6.2.1 — FN with escaped comma
  def test_spec_6_2_1_formatted_name_with_escaped_comma
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:Mr. John Q. Public\\, Esq.
      END:VCARD
    VCF

    assert_equal "Mr. John Q. Public, Esq.", attrs.formatted_name
  end

  # Section 6.2.2 — N with all five components
  def test_spec_6_2_2_structured_name
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:Mr. John Quinlan Public, Esq.
      N:Public;John;Quinlan;Mr.;Esq.
      END:VCARD
    VCF

    assert_equal "Public", attrs.family_name
    assert_equal "John", attrs.given_name
    assert_equal "Quinlan", attrs.additional_names
    assert_equal "Mr.", attrs.honorific_prefix
    assert_equal "Esq.", attrs.honorific_suffix
  end

  # Section 6.2.2 — N with multiple additional names and suffixes
  def test_spec_6_2_2_structured_name_with_multiple_values
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
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

  # Section 6.2.3 — NICKNAME
  def test_spec_6_2_3_nickname
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:Robbie
      NICKNAME:Robbie
      END:VCARD
    VCF

    assert_equal "Robbie", attrs.nickname
  end

  def test_spec_6_2_3_nickname_with_type
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:Boss
      NICKNAME;TYPE=work:Boss
      END:VCARD
    VCF

    assert_equal "Boss", attrs.nickname
  end

  # Section 6.2.4 — PHOTO with URI
  def test_spec_6_2_4_photo_with_uri
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      PHOTO:http://www.example.com/pub/photos/jqpublic.gif
      END:VCARD
    VCF

    photo = attrs.custom_properties.find { |p| p.name == "PHOTO" }
    refute_nil photo, "PHOTO property should be parsed"
    assert_equal "http://www.example.com/pub/photos/jqpublic.gif", photo.value
  end

  # Section 6.2.5 — BDAY compact format
  def test_spec_6_2_5_birthday_compact
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      BDAY:19960415
      END:VCARD
    VCF

    assert_equal "19960415", attrs.birthday
  end

  # Section 6.2.5 — BDAY with month-day only
  def test_spec_6_2_5_birthday_month_day_only
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      BDAY:--0415
      END:VCARD
    VCF

    assert_equal "--0415", attrs.birthday
  end

  # Section 6.2.5 — BDAY with VALUE=text
  def test_spec_6_2_5_birthday_text_value
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      BDAY;VALUE=text:circa 1800
      END:VCARD
    VCF

    assert_equal "circa 1800", attrs.birthday
  end

  # Section 6.2.6 — ANNIVERSARY
  def test_spec_6_2_6_anniversary
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      ANNIVERSARY:19960415
      END:VCARD
    VCF

    assert_equal "19960415", attrs.anniversary
  end

  # Section 6.2.7 — GENDER
  def test_spec_6_2_7_gender_male
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      GENDER:M
      END:VCARD
    VCF

    assert_equal "M", attrs.gender
  end

  def test_spec_6_2_7_gender_with_identity
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      GENDER:M;Fellow
      END:VCARD
    VCF

    assert_equal "M;Fellow", attrs.gender
  end

  def test_spec_6_2_7_gender_text_only
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:Someone
      GENDER:;it's complicated
      END:VCARD
    VCF

    assert_equal ";it's complicated", attrs.gender
  end

  # Section 6.3.1 — ADR with structured components
  def test_spec_6_3_1_address
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      ADR;TYPE=home:;;123 Main Street;Any Town;CA;91921-1234;U.S.A.
      END:VCARD
    VCF

    assert_equal 1, attrs.addresses.size
    addr = attrs.addresses[0]
    assert_equal "home", addr.label
    assert_equal "123 Main Street", addr.street
    assert_equal "Any Town", addr.locality
    assert_equal "CA", addr.region
    assert_equal "91921-1234", addr.postal_code
    assert_equal "U.S.A.", addr.country
  end

  # Section 6.4.1 — TEL with VALUE=uri and PREF
  def test_spec_6_4_1_telephone_with_pref
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      TEL;VALUE=uri;PREF=1;TYPE="voice,home":tel:+1-555-555-5555;ext=5555
      END:VCARD
    VCF

    assert_equal 1, attrs.phones.size
    assert_equal "tel:+1-555-555-5555;ext=5555", attrs.phones[0].number
    assert_equal 1, attrs.phones[0].pref
  end

  # Section 6.4.2 — EMAIL with TYPE=work
  def test_spec_6_4_2_email_with_type
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      EMAIL;TYPE=work:jqpublic@xyz.example.com
      END:VCARD
    VCF

    assert_equal 1, attrs.emails.size
    assert_equal "jqpublic@xyz.example.com", attrs.emails[0].address
    assert_equal "work", attrs.emails[0].label
  end

  # Section 6.4.2 — EMAIL with PREF
  def test_spec_6_4_2_email_with_pref
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:Jane Doe
      EMAIL;PREF=1:jane_doe@example.com
      END:VCARD
    VCF

    assert_equal 1, attrs.emails.size
    assert_equal "jane_doe@example.com", attrs.emails[0].address
    assert_equal 1, attrs.emails[0].pref
  end

  # Section 6.4.3 — IMPP with PREF
  def test_spec_6_4_3_impp_with_pref
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:Alice
      IMPP;PREF=1:xmpp:alice@example.com
      END:VCARD
    VCF

    assert_equal 1, attrs.instant_messages.size
    assert_equal "xmpp:alice@example.com", attrs.instant_messages[0].uri
    assert_equal 1, attrs.instant_messages[0].pref
  end

  # Section 6.5.1 — TZ as text
  def test_spec_6_5_1_timezone_text
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      TZ:Raleigh/North America
      END:VCARD
    VCF

    tz = attrs.custom_properties.find { |p| p.name == "TZ" }
    refute_nil tz, "TZ property should be parsed"
    assert_equal "Raleigh/North America", tz.value
  end

  # Section 6.5.2 — GEO with geo: URI
  def test_spec_6_5_2_geo
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      GEO:geo:37.386013,-122.082932
      END:VCARD
    VCF

    geo = attrs.custom_properties.find { |p| p.name == "GEO" }
    refute_nil geo, "GEO property should be parsed"
    assert_equal "geo:37.386013,-122.082932", geo.value
  end

  # Section 6.6.1 — TITLE
  def test_spec_6_6_1_title
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      TITLE:Research Scientist
      END:VCARD
    VCF

    title = attrs.custom_properties.find { |p| p.name == "TITLE" }
    refute_nil title, "TITLE property should be parsed"
    assert_equal "Research Scientist", title.value
  end

  # Section 6.6.2 — ROLE
  def test_spec_6_6_2_role
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      ROLE:Project Leader
      END:VCARD
    VCF

    role = attrs.custom_properties.find { |p| p.name == "ROLE" }
    refute_nil role, "ROLE property should be parsed"
    assert_equal "Project Leader", role.value
  end

  # Section 6.6.3 — LOGO with URI
  def test_spec_6_6_3_logo_with_uri
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      LOGO:http://www.example.com/pub/logos/abccorp.jpg
      END:VCARD
    VCF

    logo = attrs.custom_properties.find { |p| p.name == "LOGO" }
    refute_nil logo, "LOGO property should be parsed"
    assert_equal "http://www.example.com/pub/logos/abccorp.jpg", logo.value
  end

  # Section 6.6.4 — ORG with escaped comma
  def test_spec_6_6_4_organization
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      ORG:ABC\\, Inc.;North American Division;Marketing
      END:VCARD
    VCF

    org = attrs.custom_properties.find { |p| p.name == "ORG" }
    refute_nil org, "ORG property should be parsed"
    assert_equal "ABC, Inc.;North American Division;Marketing", org.value
  end

  # Section 6.6.6 — RELATED
  def test_spec_6_6_6_related_with_type
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      RELATED;TYPE=friend:urn:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6
      END:VCARD
    VCF

    related = attrs.custom_properties.find { |p| p.name == "RELATED" }
    refute_nil related, "RELATED property should be parsed"
    assert_equal "urn:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6", related.value
  end

  # Section 6.7.1 — CATEGORIES
  def test_spec_6_7_1_categories_single
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      CATEGORIES:TRAVEL AGENT
      END:VCARD
    VCF

    categories = attrs.custom_properties.find { |p| p.name == "CATEGORIES" }
    refute_nil categories, "CATEGORIES property should be parsed"
    assert_equal "TRAVEL AGENT", categories.value
  end

  def test_spec_6_7_1_categories_multiple
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      CATEGORIES:INTERNET,IETF,INDUSTRY,INFORMATION TECHNOLOGY
      END:VCARD
    VCF

    categories = attrs.custom_properties.find { |p| p.name == "CATEGORIES" }
    refute_nil categories, "CATEGORIES property should be parsed"
    assert_equal "INTERNET,IETF,INDUSTRY,INFORMATION TECHNOLOGY", categories.value
  end

  # Section 6.7.2 — NOTE with escaped comma and line folding
  def test_spec_6_7_2_note_with_escaped_comma
    vcf = "BEGIN:VCARD\r\nVERSION:4.0\r\nFN:John Public\r\nNOTE:This fax number is operational 0800 to 1715\r\n  EST\\, Mon-Fri.\r\nEND:VCARD\r\n"
    attrs = parse(vcf)

    assert_equal "This fax number is operational 0800 to 1715 EST, Mon-Fri.", attrs.note
  end

  # Section 6.7.3 — PRODID
  def test_spec_6_7_3_prodid
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      PRODID:-//ONLINE DIRECTORY//NONSGML Version 1//EN
      END:VCARD
    VCF

    assert_equal "-//ONLINE DIRECTORY//NONSGML Version 1//EN", attrs.product_id
  end

  # Section 6.7.4 — REV
  def test_spec_6_7_4_revision
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      REV:19951031T222710Z
      END:VCARD
    VCF

    rev = attrs.custom_properties.find { |p| p.name == "REV" }
    refute_nil rev, "REV property should be parsed"
    assert_equal "19951031T222710Z", rev.value
  end

  # Section 6.7.6 — UID with urn:uuid
  def test_spec_6_7_6_uid
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      UID:urn:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6
      END:VCARD
    VCF

    assert_equal "urn:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6", attrs.uid
  end

  # Section 5.1 — LANGUAGE parameter
  def test_spec_5_1_language_parameter
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:John Public
      ROLE;LANGUAGE=tr:hoca
      END:VCARD
    VCF

    role = attrs.custom_properties.find { |p| p.name == "ROLE" }
    refute_nil role, "ROLE property should be parsed"
    assert_equal "hoca", role.value
  end

  # Section 5.9 — SORT-AS parameter on N
  def test_spec_5_9_sort_as_parameter
    attrs = parse(<<~VCF)
      BEGIN:VCARD
      VERSION:4.0
      FN:Rene van der Harten
      N;SORT-AS="Harten,Rene":van der Harten;Rene,J.;Sir;R.D.O.N.
      END:VCARD
    VCF

    assert_equal "van der Harten", attrs.family_name
    assert_equal "Rene,J.", attrs.given_name
    assert_equal "Sir", attrs.additional_names
    assert_equal "R.D.O.N.", attrs.honorific_prefix
  end

  # Section 4.1 — NOTE with escaped newlines and commas (text value)
  def test_spec_4_1_note_with_escaped_newlines
    vcf = "BEGIN:VCARD\r\nVERSION:4.0\r\nFN:John Public\r\nNOTE:Mythical Manager\\nHyjinx Software Division\\n\r\n BabsCo\\, Inc.\\n\r\nEND:VCARD\r\n"
    attrs = parse(vcf)

    assert_equal "Mythical Manager\nHyjinx Software Division\nBabsCo, Inc.\n", attrs.note
  end

  private
    def parse(vcf_text)
      Vcardfull::Parser::V40.new(vcf_text).parse
    end
end
