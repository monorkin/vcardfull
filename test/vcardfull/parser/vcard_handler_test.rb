require_relative "../../test_helper"
require "tempfile"

class Vcardfull::Parser::VCardHandlerTest < Minitest::Test
  def test_on_property_sets_version
    handler = build_handler
    handler.on_property("VERSION", {}, "4.0", type: nil, pref: nil)

    assert_equal "4.0", handler.result.version
  end

  def test_on_property_sets_uid
    handler = build_handler
    handler.on_property("UID", {}, "abc-123", type: nil, pref: nil)

    assert_equal "abc-123", handler.result.uid
  end

  def test_on_property_unescapes_formatted_name
    handler = build_handler
    handler.on_property("FN", {}, "Smith\\, Alice", type: nil, pref: nil)

    assert_equal "Smith, Alice", handler.result.formatted_name
  end

  def test_on_property_parses_structured_name
    handler = build_handler
    handler.on_property("N", {}, "Smith;Alice;B.;Dr.;Jr.", type: nil, pref: nil)

    result = handler.result
    assert_equal "Smith", result.family_name
    assert_equal "Alice", result.given_name
    assert_equal "B.", result.additional_names
    assert_equal "Dr.", result.honorific_prefix
    assert_equal "Jr.", result.honorific_suffix
  end

  def test_on_property_sets_nil_for_empty_structured_name_parts
    handler = build_handler
    handler.on_property("N", {}, "Smith;Alice;;;", type: nil, pref: nil)

    result = handler.result
    assert_equal "Smith", result.family_name
    assert_equal "Alice", result.given_name
    assert_nil result.additional_names
    assert_nil result.honorific_prefix
    assert_nil result.honorific_suffix
  end

  def test_on_property_sets_simple_properties
    handler = build_handler
    handler.on_property("KIND", {}, "individual", type: nil, pref: nil)
    handler.on_property("NICKNAME", {}, "Ali", type: nil, pref: nil)
    handler.on_property("BDAY", {}, "1990-01-15", type: nil, pref: nil)
    handler.on_property("ANNIVERSARY", {}, "2020-06-01", type: nil, pref: nil)
    handler.on_property("GENDER", {}, "F", type: nil, pref: nil)
    handler.on_property("NOTE", {}, "A friend", type: nil, pref: nil)
    handler.on_property("PRODID", {}, "-//Test//EN", type: nil, pref: nil)

    result = handler.result
    assert_equal "individual", result.kind
    assert_equal "Ali", result.nickname
    assert_equal "1990-01-15", result.birthday
    assert_equal "2020-06-01", result.anniversary
    assert_equal "F", result.gender
    assert_equal "A friend", result.note
    assert_equal "-//Test//EN", result.product_id
  end

  def test_on_property_collects_emails_with_position
    handler = build_handler
    handler.on_property("EMAIL", {}, "alice@home.com", type: "home", pref: 1)
    handler.on_property("EMAIL", {}, "alice@work.com", type: "work", pref: nil)

    result = handler.result
    assert_equal 2, result.emails.size
    assert_equal "alice@home.com", result.emails[0].address
    assert_equal "home", result.emails[0].label
    assert_equal 1, result.emails[0].pref
    assert_equal 0, result.emails[0].position
    assert_equal "alice@work.com", result.emails[1].address
    assert_equal 1, result.emails[1].position
  end

  def test_on_property_collects_phones_with_position
    handler = build_handler
    handler.on_property("TEL", {}, "+1-555-0100", type: "cell", pref: 1)

    result = handler.result
    assert_equal 1, result.phones.size
    assert_equal "+1-555-0100", result.phones[0].number
    assert_equal "cell", result.phones[0].label
    assert_equal 0, result.phones[0].position
  end

  def test_on_property_parses_addresses
    handler = build_handler
    handler.on_property("ADR", {}, ";;123 Main St;Springfield;IL;62701;US", type: "home", pref: 1)

    result = handler.result
    assert_equal 1, result.addresses.size
    addr = result.addresses[0]
    assert_equal "123 Main St", addr.street
    assert_equal "Springfield", addr.locality
    assert_equal "IL", addr.region
    assert_equal "62701", addr.postal_code
    assert_equal "US", addr.country
    assert_equal "home", addr.label
    assert_equal 1, addr.pref
  end

  def test_on_property_collects_urls
    handler = build_handler
    handler.on_property("URL", {}, "https://example.com", type: "home", pref: nil)

    result = handler.result
    assert_equal 1, result.urls.size
    assert_equal "https://example.com", result.urls[0].url
    assert_equal "home", result.urls[0].label
  end

  def test_on_property_collects_instant_messages
    handler = build_handler
    handler.on_property("IMPP", {}, "xmpp:alice@example.com", type: "home", pref: nil)

    result = handler.result
    assert_equal 1, result.instant_messages.size
    assert_equal "xmpp:alice@example.com", result.instant_messages[0].uri
  end

  def test_on_property_collects_custom_properties
    handler = build_handler
    handler.on_property("ORG", { "TYPE" => "work" }, "Acme Corp", type: "work", pref: nil)

    result = handler.result
    assert_equal 1, result.custom_properties.size
    assert_equal "ORG", result.custom_properties[0].name
    assert_equal "Acme Corp", result.custom_properties[0].value
    assert_equal "TYPE=work", result.custom_properties[0].params
  end

  def test_on_property_skips_begin_and_end
    handler = build_handler
    handler.on_property("BEGIN", {}, "VCARD", type: nil, pref: nil)
    handler.on_property("END", {}, "VCARD", type: nil, pref: nil)

    result = handler.result
    assert_empty result.custom_properties
  end

  def test_on_property_case_insensitive_property_names
    handler = build_handler
    handler.on_property("fn", {}, "Alice", type: nil, pref: nil)

    assert_equal "Alice", handler.result.formatted_name
  end

  def test_position_counters_are_independent_per_type
    handler = build_handler
    handler.on_property("EMAIL", {}, "a@b.com", type: nil, pref: nil)
    handler.on_property("TEL", {}, "+1-555-0100", type: nil, pref: nil)
    handler.on_property("EMAIL", {}, "c@d.com", type: nil, pref: nil)

    result = handler.result
    assert_equal 0, result.emails[0].position
    assert_equal 0, result.phones[0].position
    assert_equal 1, result.emails[1].position
  end

  private
    def build_handler
      Vcardfull::Parser::VCardHandler.new(unescape: method(:default_unescape))
    end

    def default_unescape(value)
      value.gsub("\\n", "\n").gsub("\\N", "\n").gsub("\\,", ",").gsub("\\;", ";").gsub("\\\\", "\\")
    end
end
