import 'dart:convert';
import 'dart:typed_data';

/// Returns the provider-facing MIME for a prompt attachment, or null only
/// when there is nothing honest to call it. OpenCode expands exact
/// `text/plain` data URLs into text instead of sending them to a model as
/// arbitrary file parts; every other MIME goes through as a file part, so
/// archives and other binaries attach fine — a `zip` is `application/zip`,
/// not "unsupported". The model or the agent decides what it can read; the
/// picker is not the place for a format whitelist.
String? promptAttachmentMime({
  required String filename,
  required Uint8List bytes,
  String? declaredMime,
}) {
  final declared = declaredMime?.split(';').first.trim().toLowerCase() ?? '';
  final normalizedMedia = switch (declared) {
    'image/png' => 'image/png',
    'image/jpeg' || 'image/jpg' => 'image/jpeg',
    'image/gif' => 'image/gif',
    'image/webp' => 'image/webp',
    'application/pdf' => 'application/pdf',
    // Any image type the platform names passes through as itself — the OS
    // MIME is the honest word when the extension could be lying.
    _ when declared.startsWith('image/') => declared,
    _ => null,
  };
  if (normalizedMedia != null) return normalizedMedia;
  if (_isPromptTextMime(declared)) {
    if (bytes.isNotEmpty && !_looksLikePromptText(bytes)) return null;
    return 'text/plain';
  }

  final extension = filename.contains('.')
      ? filename.split('.').last.toLowerCase()
      : '';
  final inferred = switch (extension) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'tif' || 'tiff' => 'image/tiff',
    'ico' => 'image/x-icon',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'avif' => 'image/avif',
    'pdf' => 'application/pdf',
    'zip' => 'application/zip',
    '7z' => 'application/x-7z-compressed',
    'rar' => 'application/vnd.rar',
    'tar' => 'application/x-tar',
    'gz' || 'tgz' => 'application/gzip',
    'bz2' => 'application/x-bzip2',
    'xz' => 'application/x-xz',
    'zst' => 'application/zstd',
    'jar' => 'application/java-archive',
    'apk' => 'application/vnd.android.package-archive',
    'dmg' => 'application/x-apple-diskimage',
    'iso' => 'application/x-iso9660-image',
    'exe' || 'msi' => 'application/x-msdownload',
    'dll' => 'application/vnd.microsoft.portable-executable',
    'so' || 'a' || 'o' => 'application/x-sharedlib',
    'dylib' => 'application/x-sharedlib',
    'elf' => 'application/x-elf',
    'dex' || 'odex' || 'vdex' || 'art' || 'oat' => 'application/octet-stream',
    'deb' => 'application/vnd.debian.binary-package',
    'rpm' => 'application/x-rpm',
    'wasm' => 'application/wasm',
    'class' => 'application/java-vm',
    'sqlite' || 'sqlite3' || 'db' => 'application/vnd.sqlite3',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'flac' => 'audio/flac',
    'ogg' => 'audio/ogg',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'mp4' || 'm4v' => 'video/mp4',
    'mkv' => 'video/x-matroska',
    'avi' => 'video/x-msvideo',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'ttf' => 'font/ttf',
    'otf' => 'font/otf',
    'woff' => 'font/woff',
    'woff2' => 'font/woff2',
    'epub' => 'application/epub+zip',
    'md' ||
    'markdown' ||
    'txt' ||
    'log' ||
    'html' ||
    'htm' ||
    'css' ||
    'csv' ||
    'json' ||
    'xml' ||
    'yaml' ||
    'yml' ||
    'toml' ||
    'dart' ||
    'js' ||
    'ts' ||
    'tsx' ||
    'jsx' ||
    'py' ||
    'go' ||
    'rs' ||
    'java' ||
    'kt' ||
    'kts' ||
    'c' ||
    'cc' ||
    'cpp' ||
    'h' ||
    'hpp' ||
    'sh' ||
    'sql' => 'text/plain',
    _ => null,
  };
  if (inferred != null) {
    if (inferred == 'text/plain' &&
        bytes.isNotEmpty &&
        !_looksLikePromptText(bytes)) {
      // The extension claims text but the bytes say binary — honour the
      // bytes and pass the file through rather than rejecting it.
      return declared.isNotEmpty && !_isPromptTextMime(declared)
          ? declared
          : 'application/octet-stream';
    }
    return inferred;
  }
  if ((declared.isEmpty || declared == 'application/octet-stream') &&
      _looksLikePromptText(bytes)) {
    return 'text/plain';
  }
  // Any remaining binary — a declared application/* type, an unknown
  // extension, no extension at all — attaches as itself.
  return declared.isNotEmpty ? declared : 'application/octet-stream';
}

bool _isPromptTextMime(String mime) =>
    mime.startsWith('text/') ||
    mime == 'application/json' ||
    mime == 'application/javascript' ||
    mime == 'application/x-javascript' ||
    mime == 'application/xml' ||
    mime == 'application/yaml' ||
    mime == 'application/x-yaml' ||
    mime == 'application/toml' ||
    mime == 'application/x-sh' ||
    mime == 'application/sql' ||
    mime == 'application/graphql' ||
    mime == 'application/x-ndjson' ||
    mime.endsWith('+json') ||
    mime.endsWith('+xml');

bool _looksLikePromptText(Uint8List bytes) {
  if (bytes.isEmpty || bytes.contains(0)) return false;
  try {
    final text = utf8.decode(bytes, allowMalformed: false);
    return !text.runes.any(
      (rune) => rune < 0x09 || (rune > 0x0D && rune < 0x20),
    );
  } on FormatException {
    return false;
  }
}
