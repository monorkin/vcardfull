# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "vcardfull"
  spec.version = "0.1.0"
  spec.authors = [ "Stanko K.R." ]
  spec.summary = "A vCard parser and serializer supporting versions 2.1, 3.0, and 4.0"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "base64"
  spec.add_dependency "stringio"
end
