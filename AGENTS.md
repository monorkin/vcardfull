# VCardfull

This is a VCard 2.1, 3.0 and 4.0 parser and serializer for Ruby.
It supports all the features of the vCard standard, including multi-valued properties, parameters, and different encodings.

## Development Commands

### Testing
```bash
rake test                                   # Run unit tests (fast)
rake test TEST=test/path/file_test.rb       # Run single test file
```

## Architecture Overview

### Parsing

While in vCards are usually small, with the advent of smartphones with 200 megapixel cameras, vCards can now contain large photos and other media. To handle this efficiently, VCardfull uses a streaming parser that processes the vCard data in chunks, allowing it to handle large files without consuming excessive memory.

Fields smaller than a configurable treshold (default: 1MB) are buffered in memory for quick access, while larger fields are written to temporary files on disk. This approach ensures that VCardfull can handle vCards of any size without running into memory issues.

The streaming parser functions similarly to a SAX parser, emitting events as it processes the vCard data. This allows for efficient parsing and serialization, as well as the ability to handle large vCards without blocking the main thread.

## Coding style

@STYLE.md
