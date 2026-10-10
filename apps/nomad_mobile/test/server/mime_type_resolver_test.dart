import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/server/mime_type_resolver.dart';

void main() {
  group('MimeTypeResolver Tests', () {
    test('resolves standard web files correctly', () {
      expect(MimeTypeResolver.resolve('index.html'),
          equals('text/html; charset=utf-8'));
      expect(MimeTypeResolver.resolve('style.css'),
          equals('text/css; charset=utf-8'));
      expect(MimeTypeResolver.resolve('script.js'),
          equals('application/javascript; charset=utf-8'));
      expect(MimeTypeResolver.resolve('module.mjs'),
          equals('application/javascript; charset=utf-8'));
      expect(MimeTypeResolver.resolve('config.json'),
          equals('application/json; charset=utf-8'));
    });

    test('is case-insensitive', () {
      expect(MimeTypeResolver.resolve('INDEX.HTML'),
          equals('text/html; charset=utf-8'));
      expect(MimeTypeResolver.resolve('Style.Css'),
          equals('text/css; charset=utf-8'));
      expect(MimeTypeResolver.resolve('SCRIPT.JS'),
          equals('application/javascript; charset=utf-8'));
    });

    test('handles path strings correctly', () {
      expect(MimeTypeResolver.resolve('css/responsive.css'),
          equals('text/css; charset=utf-8'));
      expect(MimeTypeResolver.resolve('/assets/images/logo.png'),
          equals('image/png'));
      expect(MimeTypeResolver.resolve('C:\\\\Documents\\\\index.htm'),
          equals('text/html; charset=utf-8'));
    });

    test('resolves common image formats and assets', () {
      expect(MimeTypeResolver.resolve('icon.ico'), equals('image/x-icon'));
      expect(MimeTypeResolver.resolve('image.jpg'), equals('image/jpeg'));
      expect(MimeTypeResolver.resolve('image.jpeg'), equals('image/jpeg'));
      expect(MimeTypeResolver.resolve('image.png'), equals('image/png'));
      expect(MimeTypeResolver.resolve('vector.svg'), equals('image/svg+xml'));
      expect(MimeTypeResolver.resolve('animation.gif'), equals('image/gif'));
      expect(MimeTypeResolver.resolve('modern.webp'), equals('image/webp'));
      expect(MimeTypeResolver.resolve('notes.txt'),
          equals('text/plain; charset=utf-8'));
    });

    test('returns fallback for unknown or missing extensions', () {
      expect(MimeTypeResolver.resolve('no_extension'),
          equals('application/octet-stream'));
      expect(MimeTypeResolver.resolve('file.unknown_ext'),
          equals('application/octet-stream'));
      expect(MimeTypeResolver.resolve('.'), equals('application/octet-stream'));
      expect(MimeTypeResolver.resolve('ends_with_dot.'),
          equals('application/octet-stream'));
      expect(MimeTypeResolver.resolve(''), equals('application/octet-stream'));
    });
  });
}
