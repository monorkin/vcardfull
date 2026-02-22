require_relative "../test_helper"

class Vcardfull::VCardTest < Minitest::Test
  def test_initializes_with_keyword_arguments
    vcard = Vcardfull::VCard.new(uid: "abc", formatted_name: "Alice")

    assert_equal "abc", vcard.uid
    assert_equal "Alice", vcard.formatted_name
  end

  def test_defaults_collections_to_empty_arrays
    vcard = Vcardfull::VCard.new(uid: "abc", formatted_name: "Alice")

    assert_equal [], vcard.emails
    assert_equal [], vcard.phones
    assert_equal [], vcard.addresses
    assert_equal [], vcard.urls
    assert_equal [], vcard.instant_messages
    assert_equal [], vcard.custom_properties
  end

  def test_wraps_hashes_into_structs_for_all_collection_properties
    vcard = Vcardfull::VCard.new(
      uid: "abc",
      formatted_name: "Alice",
      emails: [ { address: "alice@example.com", label: "home", pref: 1 } ],
      phones: [ { number: "+1-555-0100", label: "cell", pref: 1 } ],
      addresses: [ { street: "123 Main St", locality: "Springfield", region: "IL", label: "home" } ],
      urls: [ { url: "https://example.com", label: "home" } ],
      instant_messages: [ { uri: "xmpp:alice@example.com", label: "home" } ],
      custom_properties: [ { name: "ORG", value: "Acme Corp", params: nil } ]
    )

    assert_instance_of Vcardfull::VCard::Email, vcard.emails[0]
    assert_equal "alice@example.com", vcard.emails[0].address
    assert_equal "home", vcard.emails[0].label
    assert_equal 1, vcard.emails[0].pref

    assert_instance_of Vcardfull::VCard::Phone, vcard.phones[0]
    assert_equal "+1-555-0100", vcard.phones[0].number

    assert_instance_of Vcardfull::VCard::Address, vcard.addresses[0]
    assert_equal "123 Main St", vcard.addresses[0].street

    assert_instance_of Vcardfull::VCard::Url, vcard.urls[0]
    assert_equal "https://example.com", vcard.urls[0].url

    assert_instance_of Vcardfull::VCard::InstantMessage, vcard.instant_messages[0]
    assert_equal "xmpp:alice@example.com", vcard.instant_messages[0].uri

    assert_instance_of Vcardfull::VCard::CustomProperty, vcard.custom_properties[0]
    assert_equal "ORG", vcard.custom_properties[0].name
  end

  def test_preserves_existing_struct_instances
    email = Vcardfull::VCard::Email.new(address: "alice@example.com", label: "home")
    vcard = Vcardfull::VCard.new(uid: "abc", formatted_name: "Alice", emails: [ email ])

    assert_same email, vcard.emails[0]
  end

  def test_to_vcf_delegates_to_serializer
    vcard = Vcardfull::VCard.new(
      version: "4.0",
      uid: "abc",
      formatted_name: "Alice"
    )

    vcf = vcard.to_vcf

    assert_kind_of String, vcf
    assert_includes vcf, "BEGIN:VCARD"
    assert_includes vcf, "UID:abc"
    assert_includes vcf, "FN:Alice"
    assert_includes vcf, "END:VCARD"
  end
end
