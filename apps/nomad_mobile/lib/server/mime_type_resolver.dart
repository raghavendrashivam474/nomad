/// Maps supported file extensions to MIME types.
class MimeTypeResolver {
  static const Map<String, String> _map = {
    'html': 'text/html; charset=utf-8',
    'htm': 'text/html; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'js': 'application/javascript; charset=utf-8',
    'mjs': 'application/javascript; charset=utf-8',
    'json': 'application/json; charset=utf-8',
    'svg': 'image/svg+xml',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'ico': 'image/x-icon',
    'txt': 'text/plain; charset=utf-8',
  };

  /// Resolves the MIME type for a given filename or path.
  ///
  /// Handles extensions in a case-insensitive manner and returns
  /// a deterministic fallback 'application/octet-stream' for unknown extensions.
  static String resolve(String path) {
    final normalized = path.trim().toLowerCase();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == normalized.length - 1) {
      return 'application/octet-stream';
    }
    final ext = normalized.substring(dotIndex + 1);
    return _map[ext] ?? 'application/octet-stream';
  }
}
