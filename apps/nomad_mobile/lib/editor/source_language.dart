/// Represents supported programming/markup languages recognized by Nomad.
enum SourceLanguage {
  html('HTML', ['html', 'htm']),
  css('CSS', ['css']),
  javascript('JavaScript', ['js', 'mjs', 'cjs']),
  kotlin('Kotlin', ['kt', 'kts']),
  xml('XML', ['xml']),
  gradle('Gradle', ['gradle']),
  plainText('Plain Text', ['txt', 'md', 'properties']);

  final String displayName;
  final List<String> extensions;

  const SourceLanguage(this.displayName, this.extensions);

  /// Resolves the SourceLanguage from a file name or path.
  static SourceLanguage fromFileName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return SourceLanguage.plainText;
    }
    final ext = fileName.substring(dotIndex + 1).toLowerCase();
    for (final lang in SourceLanguage.values) {
      if (lang.extensions.contains(ext)) {
        return lang;
      }
    }
    return SourceLanguage.plainText;
  }
}