import 'dart:async';
import 'dart:io';
import 'package:nomad_core/nomad_core.dart';
import 'mime_type_resolver.dart';
import 'project_file_resolver.dart';

/// Embedded HTTP server that serves project workspace files to local clients (e.g. WebView).
/// 
/// Strictly binds to loopback IPv4 (127.0.0.1) and enforces project path scoping.
class ProjectFileServer {
  final ProjectFileResolver resolver;
  final int port;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  ProjectFileServer({
    required this.resolver,
    this.port = 18080,
  });

  /// Whether the server is currently bound and listening.
  bool get isRunning => _server != null;

  /// The actual bound port (available after [start]).
  int? get boundPort => _server?.port;

  /// Starts the server on 127.0.0.1:[port].
  /// 
  /// Throws [SocketException] if the port cannot be bound.
  Future<void> start() async {
    if (isRunning) return;

    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
      shared: false,
    );

    _server = server;
    _subscription = server.listen(
      _handleRequest,
      onError: (error, stackTrace) {
        // Log or handle server stream errors without crashing
      },
      cancelOnError: false,
    );
  }

  /// Stops the server and releases the bound socket.
  Future<void> stop({bool force = false}) async {
    await _subscription?.cancel();
    _subscription = null;
    await _server?.close(force: force);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    try {
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.contentType = ContentType.text;
        response.write('Method Not Allowed');
        await response.close();
        return;
      }

      final uriPath = request.uri.path;
      // Expected URL format: /<projectId>/<path/to/file>
      final segments = uriPath.split('/').where((s) => s.isNotEmpty).toList();

      if (segments.isEmpty) {
        response.statusCode = HttpStatus.badRequest;
        response.headers.contentType = ContentType.text;
        response.write('Bad Request: Project ID required');
        await response.close();
        return;
      }

      final projectIdStr = segments.first;
      final logicalSegments = segments.sublist(1);

      if (logicalSegments.isEmpty) {
        response.statusCode = HttpStatus.badRequest;
        response.headers.contentType = ContentType.text;
        response.write('Bad Request: Resource path required');
        await response.close();
        return;
      }

      final logicalPath = logicalSegments.join('/');
      final result = await resolver.resolve(EntityId(projectIdStr), logicalPath);

      if (result is FileResolutionSuccess) {
        final mimeTypeStr = MimeTypeResolver.resolve(result.node.name);
        response.statusCode = HttpStatus.ok;
        response.headers.set(HttpHeaders.contentTypeHeader, mimeTypeStr);
        response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, must-revalidate');
        
        if (request.method == 'GET') {
          response.add(result.bytes);
        }
        await response.close();
      } else if (result is FileResolutionFailure) {
        if (result.errorType == FileResolutionErrorType.invalidPath ||
            result.errorType == FileResolutionErrorType.pathTraversal) {
          response.statusCode = HttpStatus.forbidden;
          response.headers.contentType = ContentType.text;
          response.write('Forbidden: Invalid resource path');
        } else {
          response.statusCode = HttpStatus.notFound;
          response.headers.contentType = ContentType.text;
          response.write('Not Found');
        }
        await response.close();
      }
    } catch (e) {
      try {
        response.statusCode = HttpStatus.internalServerError;
        response.headers.contentType = ContentType.text;
        response.write('Internal Server Error');
        await response.close();
      } catch (_) {
        // Connection may have already been closed/aborted
      }
    }
  }
}
