import 'dart:convert';
import 'dart:io';

import 'package:jaspr_storybook/metadata.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.isEmpty) {
    stdout.writeln(
      'dart run jaspr_storybook:metadata --config <json> --output <json> [--check]',
    );
    return;
  }
  try {
    String option(String key) {
      final index = args.indexOf(key);
      if (index < 0 || index + 1 == args.length) {
        throw ArgumentError('Missing $key');
      }
      return args[index + 1];
    }

    final output = File(option('--output'));
    final config = File(option('--config'));
    final metadata = await generateMetadata(config);
    final root = p.normalize(
      p.join(p.dirname(config.absolute.path), metadata['root'] as String),
    );
    metadata['root'] = p.relative(root, from: p.dirname(output.absolute.path));
    final content = '${const JsonEncoder.withIndent('  ').convert(metadata)}\n';
    if (args.contains('--check')) {
      if (!output.existsSync() || output.readAsStringSync() != content) {
        throw StateError('Jaspr metadata is stale: ${output.path}');
      }
    } else {
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(content);
    }
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
