import 'dart:io';
import 'dart:typed_data';
import 'package:arrow_escape/data/level_generator/level_generator_v2.dart';
import 'package:arrow_escape/data/level_binary_codec.dart';
import 'package:arrow_escape/data/models/level.dart';

void main() async {
  print('Starting pregeneration of all 2000 levels matching level schedule...');
  final stopwatch = Stopwatch()..start();

  final List<LevelModel> levels = [];
  for (int i = 1; i <= 2000; i++) {
    final level = LevelGeneratorV2.generateLevel(i);
    levels.add(level);
    if (i % 100 == 0 || i == 2000) {
      print('Generated $i / 2000 levels (${stopwatch.elapsedMilliseconds} ms)...');
    }
  }

  stopwatch.stop();
  print('Generated 2000 levels in ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)} seconds.');

  print('Encoding levels into binary format (v2)...');
  final Uint8List binaryData = encodeLevels(levels);
  
  final outFile = File('assets/levels.bin');
  await outFile.writeAsBytes(binaryData);
  print('Successfully saved updated assets/levels.bin (${(binaryData.length / 1024).toStringAsFixed(1)} KB, 2000 levels).');
}
