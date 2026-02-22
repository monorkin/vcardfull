# VCardfull

A vCard parser and serializer for supporting versions 2.1, 3.0, and 4.0.

Supports all features of the vCard standard, including multi-valued properties, parameters, and different encodings. Uses a streaming parser that efficiently handles large vCards (e.g. those with high-resolution photos) without excessive memory consumption.

## Installation

Add to your Gemfile:

```ruby
gem "vcardfull"
```

## Usage

### Parsing

The quickest way to parse a vCard is with `Vcardfull::Parser.parse`, which auto-detects the version and returns a `VCard` object:

```ruby
vcard = Vcardfull::Parser.parse(vcf_string)

vcard.formatted_name  # => "Alice Smith"
vcard.emails.first    # => #<Vcardfull::VCard::Email address="alice@example.com" label="home" pref=1>
```

You can also pass an IO object for streaming input:

```ruby
File.open("contact.vcf") do |file|
  vcard = Vcardfull::Parser.parse(file)
end
```

### Serializing

Serialize a `VCard` back to vCard format with `#to_vcf`:

```ruby
vcard = Vcardfull::VCard.new(
  version: "4.0",
  uid: "abc-123",
  formatted_name: "Alice Smith",
  family_name: "Smith",
  given_name: "Alice",
  emails: [{ address: "alice@example.com", label: "home", pref: 1 }],
  phones: [{ number: "+1-555-0100", label: "cell", pref: 1 }]
)

vcard.to_vcf
# => "BEGIN:VCARD\r\nVERSION:4.0\r\nUID:abc-123\r\n..."
```

### Large values

By default, property values larger than 1 MB (e.g. embedded photos) are streamed to temporary files on disk instead of being buffered in memory. You can configure this threshold:

```ruby
vcard = Vcardfull::Parser.parse(input, large_value_threshold: 512 * 1024) # 512 KB
vcard = Vcardfull::Parser.parse(input, large_value_threshold: 0) # Everything is streamed to disk
vcard = Vcardfull::Parser.parse(input, large_value_threshold: Float::INFINITY) # Everything is buffered in memory
```

Large values are returned as `Tempfile` objects instead of strings:

```ruby
photo = vcard.custom_properties.find { |p| p.name == "PHOTO" }

if photo.value.respond_to?(:read)
  photo.value.read # => binary data
else
  photo.value      # => string
end
```

## VCard attributes

A `Vcardfull::VCard` exposes the following attributes:

| Attribute | Type | Description |
|---|---|---|
| `version` | `String` | vCard version (`"2.1"`, `"3.0"`, or `"4.0"`) |
| `uid` | `String` | Unique identifier |
| `formatted_name` | `String` | Display name (FN) |
| `family_name` | `String` | Family/last name |
| `given_name` | `String` | Given/first name |
| `additional_names` | `String` | Middle names |
| `honorific_prefix` | `String` | Name prefix (e.g. "Dr.") |
| `honorific_suffix` | `String` | Name suffix (e.g. "Jr.") |
| `kind` | `String` | Entity kind (e.g. "individual") |
| `nickname` | `String` | Nickname |
| `birthday` | `String` | Date of birth |
| `anniversary` | `String` | Anniversary date |
| `gender` | `String` | Gender |
| `note` | `String` | Free-text note |
| `product_id` | `String` | Producing software identifier |
| `emails` | `Array<Email>` | Email addresses |
| `phones` | `Array<Phone>` | Phone numbers |
| `addresses` | `Array<Address>` | Postal addresses |
| `urls` | `Array<Url>` | URLs |
| `instant_messages` | `Array<InstantMessage>` | Instant messaging handles |
| `custom_properties` | `Array<CustomProperty>` | Non-standard and unrecognized properties |

### Collection types

Each collection item is a Struct with typed fields:

- **Email** — `address`, `label`, `pref`, `position`
- **Phone** — `number`, `label`, `pref`, `position`
- **Address** — `po_box`, `extended`, `street`, `locality`, `region`, `postal_code`, `country`, `label`, `pref`, `position`
- **Url** — `url`, `label`, `pref`, `position`
- **InstantMessage** — `uri`, `label`, `pref`, `position`
- **CustomProperty** — `name`, `value`, `params`, `position`

The `label` field contains the first TYPE parameter value (e.g. `"home"`, `"work"`, `"cell"`). The `pref` field contains the integer preference order when specified. The `position` field preserves the original ordering of properties within each group.

### Custom handlers

The parser uses a SAX-style handler to process property events. You can replace the built-in handler with your own to customize how properties are collected. A handler must implement two methods:

- `on_property(name, params, value, type:, pref:)` — called for each vCard property
- `result` — called after parsing completes, returns whatever you need

For example, to extract only email addresses:

```ruby
class EmailCollector
  attr_reader :result

  def initialize
    @result = []
  end

  def on_property(name, params, value, type:, pref:)
    if name.upcase == "EMAIL"
      @result << value
    end
  end
end

handler = EmailCollector.new
emails = Vcardfull::Parser.parse(vcf_string, handler: handler)
# => ["alice@example.com", "alice@work.com"]
```

## Version support

VCardfull handles the differences between vCard versions transparently:

- **vCard 4.0** (RFC 6350) — the default, used when no version is detected
- **vCard 3.0** (RFC 2426) — handles bare type parameters (e.g. `TEL;CELL:...`) and PREF as a type value
- **vCard 2.1** — decodes QUOTED-PRINTABLE and BASE64 encoded values, handles soft line breaks

## License

Released under the [MIT License](LICENSE).
