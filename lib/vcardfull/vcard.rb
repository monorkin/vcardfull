# frozen_string_literal: true

module Vcardfull
  # Represents a parsed vCard with all standard properties.
  #
  # Scalar properties (version, uid, formatted_name, etc.) are stored as
  # simple values. Collection properties (emails, phones, addresses, urls,
  # instant_messages, custom_properties) are arrays of typed value objects.
  class VCard < Struct.new(
    :version, :uid, :formatted_name,
    :family_name, :given_name, :additional_names, :honorific_prefix, :honorific_suffix,
    :kind, :nickname, :birthday, :anniversary, :gender, :note, :product_id,
    :emails, :phones, :addresses, :urls, :instant_messages, :custom_properties,
    keyword_init: true
  )
    autoload :Email, "vcardfull/vcard/email"
    autoload :Phone, "vcardfull/vcard/phone"
    autoload :Address, "vcardfull/vcard/address"
    autoload :Url, "vcardfull/vcard/url"
    autoload :InstantMessage, "vcardfull/vcard/instant_message"
    autoload :CustomProperty, "vcardfull/vcard/custom_property"

    # Creates a new VCard, wrapping collection data in typed value objects.
    #
    # @param kwargs [Hash] keyword arguments matching the Struct members.
    def initialize(**)
      super
      self.emails = Array(self.emails).map { |data| Email.wrap(data) }
      self.phones = Array(self.phones).map { |data| Phone.wrap(data) }
      self.addresses = Array(self.addresses).map { |data| Address.wrap(data) }
      self.urls = Array(self.urls).map { |data| Url.wrap(data) }
      self.instant_messages = Array(self.instant_messages).map { |data| InstantMessage.wrap(data) }
      self.custom_properties = Array(self.custom_properties).map { |data| CustomProperty.wrap(data) }
    end

    # Serializes this vCard to a vCard format string.
    #
    # @return [String] the vCard data with CRLF line endings.
    def to_vcf
      Serializer.new(self).to_vcf
    end
  end
end
