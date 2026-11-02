/// Supported in-app preview routes. The extension is a routing hint, not a
/// guarantee that the underlying Android codec understands the file.
enum ViewerKind { pdf, office, text, image, audio, video, unsupported }

class ViewerFormat {
  const ViewerFormat._();

  static const _images = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'heic',
    'heif',
    'avif',
  };
  static const _office = {'docx', 'xlsx', 'pptx', 'odt'};
  static const _text = {
    'txt',
    'csv',
    'md',
    'markdown',
    'json',
    'xml',
    'html',
    'svg',
    'htm',
    'log',
    'yaml',
    'yml',
    'ini',
    'css',
    'dart',
    'java',
    'kt',
    'py',
  };
  static const _audio = {'mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'opus'};
  // Android Media3 does not provide an AVI extractor. Do not claim an
  // in-app preview for a container the bundled player cannot open.
  static const _video = {'mp4', 'm4v', 'mov', 'mkv', 'webm', '3gp'};

  static String extension(String name) {
    final period = name.lastIndexOf('.');
    return period <= 0 || period == name.length - 1
        ? ''
        : name.substring(period + 1).toLowerCase();
  }

  static ViewerKind forName(String name) {
    final ext = extension(name);
    if (ext == 'pdf') return ViewerKind.pdf;
    if (_office.contains(ext)) return ViewerKind.office;
    if (_text.contains(ext)) return ViewerKind.text;
    if (_images.contains(ext)) return ViewerKind.image;
    if (_audio.contains(ext)) return ViewerKind.audio;
    if (_video.contains(ext)) return ViewerKind.video;
    return ViewerKind.unsupported;
  }

  static String description(ViewerKind kind) => switch (kind) {
    ViewerKind.pdf => 'Read-only PDF preview',
    ViewerKind.office => 'Offline PDF-based document preview',
    ViewerKind.text => 'Plain-text preview',
    ViewerKind.image => 'Image preview with pinch-to-zoom',
    ViewerKind.audio => 'Local audio playback',
    ViewerKind.video => 'Local video playback',
    ViewerKind.unsupported => 'Preview not supported yet',
  };
}
