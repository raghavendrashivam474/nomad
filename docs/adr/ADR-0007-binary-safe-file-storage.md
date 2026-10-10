# ADR-0007: Binary-Safe File Content Storage and Serving

**Status:** Accepted
**Sprint:** MF-3
**Supersedes:** None (extends ADR-0004)

## 1. Problem

The existing `FileContentRepository` contract exposes only `String`-based
`readFile()` and `writeFile()` methods. `LocalFileContentRepository`
persists content via `readAsStringSync()` / `writeAsStringSync()`.

`ProjectFileResolver` recovers bytes for HTTP serving by calling
`utf8.encode(await contentRepository.readFile(...))`. This String
round-trip corrupts any content that is not valid UTF-8 text — notably
PNG, JPEG, GIF, WebP, ICO, WOFF, and WOFF2 binary assets.

## 2. Evidence

- `LocalFileContentRepository._getFile()` stores all content as
  `{uuid}.txt` and reads it back as a Dart `String`.
- `ProjectFileResolver.resolve()` line ~144 performs
  `utf8.encode(textContent)` on the returned String.
- Arbitrary binary bytes cannot survive a decode-to-String /
  re-encode-to-bytes round-trip without loss.

## 3. Options Considered

| Option | Description | Drawback |
|--------|-------------|----------|
| A. Replace String API with `List<int>` everywhere | Convert all callers to byte arrays | Breaks editor, starter projects, and all existing tests; massive scope |
| B. Base64-encode binary in the existing String API | Store binary as Base64 text | Doubles storage size; adds encode/decode complexity; fragile |
| C. Add parallel byte-oriented methods (selected) | Add `readFileBytes()` / `writeFileBytes()` alongside existing String API | Two APIs to maintain; minimal surface area |
| D. Separate asset storage subsystem | New database/table for binary assets | Over-engineered for current scope; violates minimal-change principle |

## 4. Selected Approach — Option C

Add `readFileBytes()` and `writeFileBytes()` to `FileContentRepository`
with default implementations that delegate to the existing String methods
(via `utf8.encode` / `utf8.decode`) for backward compatibility.

Override in `LocalFileContentRepository` with `readAsBytesSync()` /
`writeAsBytesSync()` to preserve exact bytes on disk.

Update `ProjectFileResolver` to call `readFileBytes()` instead of
`readFile()` + `utf8.encode()`. The HTTP server already serves
`List<int>` bytes, so no server changes are needed.

## 5. Compatibility

- Existing `readFile()` / `writeFile()` callers (editor, starter
  projects, tests) are **unchanged**.
- Existing on-disk `{uuid}.txt` files remain valid. For text content,
  `readAsBytesSync()` returns the same UTF-8 bytes that
  `utf8.encode(readAsStringSync())` previously produced.
- No database schema migration is required. `FileNode` metadata is
  unchanged.
- The physical `.txt` extension on stored files is cosmetic and
  irrelevant to byte-level I/O.

## 6. Migration

No migration is required. Existing text files are byte-compatible.
Binary files created via the new `writeFileBytes()` path will be
stored alongside existing text files in the same directory structure.

## 7. Testing

- Byte round-trip tests prove exact equality for binary payloads
  including zero bytes and non-UTF-8 sequences.
- Existing text read/write tests remain green.
- Resolver tests verify binary and text resolution.
- HTTP server tests verify correct bytes, content-type, and
  content-length for binary responses.

## 8. Consequences

- The `FileContentRepository` contract now has four content methods
  instead of two. Implementations must override the byte methods
  for true binary safety.
- The editor continues to operate on text only. Binary asset
  creation/upload is a future concern outside MF-3 scope.
- MIME recognition in `MimeTypeResolver` already covers common
  image types; font types may be added as needed.
