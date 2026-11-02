import 'dart:io';
import 'dart:typed_data';

import 'package:frog_file_viewer/branding/tie_dye_launcher.dart';

/// Generates Android launcher resources by recoloring Converter's *original*
/// launcher PNGs. The source images remain unchanged and available for audit.
///
/// Run from the repository root after "flutter pub get":
///   dart run tool/generate_tie_dye_icons.dart
///
/// If Android resources do not exist yet, run "flutter create --platforms=android
/// --org com.frogdadday --project-name frog_file_viewer ." first.
Future<void> main() async {
  const root = 'assets/branding';
  const densities = <String>['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

  Future<void> recolor(String inputPath, String outputPath) async {
    final bytes = await File(inputPath).readAsBytes();
    final output = TieDyeLauncher.recolorPng(Uint8List.fromList(bytes));
    final destination = File(outputPath);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(output, flush: true);
    stdout.writeln('Created: $outputPath');
  }

  await recolor(
    '$root/source/converter_play_store_icon_512.png',
    '$root/generated/tiedye_launcher_512.png',
  );

  for (final density in densities) {
    await recolor(
      '$root/source/converter_mipmap_$density.png',
      'android/app/src/main/res/mipmap-$density/ic_launcher.png',
    );
  }
}
