import 'package:flutter_test/flutter_test.dart';
import 'package:frog_file_viewer/services/viewer_format.dart';

void main() {
  test('routes common files to correct local viewer', () {
    const expected = <String, ViewerKind>{
      'family.HEIC': ViewerKind.image,
      'photo.avif': ViewerKind.image,
      'animation.gif': ViewerKind.image,
      'clip.MP4': ViewerKind.video,
      'movie.webm': ViewerKind.video,
      'legacy.avi': ViewerKind.unsupported,
      'song.mp3': ViewerKind.audio,
      'lossless.flac': ViewerKind.audio,
      'report.DOCX': ViewerKind.office,
      'slides.pptx': ViewerKind.office,
      'budget.xlsx': ViewerKind.office,
      'notes.odt': ViewerKind.office,
      'letter.pdf': ViewerKind.pdf,
      'data.csv': ViewerKind.text,
      'config.json': ViewerKind.text,
      'readme.md': ViewerKind.text,
      'export.html': ViewerKind.text,
      'vector.svg': ViewerKind.text,
      'legacy.doc': ViewerKind.unsupported,
      'book.epub': ViewerKind.unsupported,
      'no-extension': ViewerKind.unsupported,
    };
    for (final entry in expected.entries) {
      expect(ViewerFormat.forName(entry.key), entry.value, reason: entry.key);
    }
  });

  test('extension classification does not crash on edge cases', () {
    expect(ViewerFormat.extension('.hidden'), '');
    expect(ViewerFormat.extension('file.'), '');
    expect(ViewerFormat.extension('a..PNG'), 'png');
    expect(ViewerFormat.forName('a.tar.gz'), ViewerKind.unsupported);
  });
}
