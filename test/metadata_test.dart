import 'dart:convert';
import 'dart:io';

import 'package:jaspr_storybook/metadata.dart';
import 'package:test/test.dart';

void main() {
  test(
    'extracts resolved constructor types, defaults, docs and marked examples',
    () async {
      final directory = Directory.systemTemp.createTempSync('jaspr-metadata-');
      addTearDown(() => directory.deleteSync(recursive: true));
      File('${directory.path}/components.dart').writeAsStringSync('''
/// A documented control.
class Control {
  const Control({required this.label, this.disabled = false});
  final String label;
  final bool disabled;
}
// #docregion control
const sample = Control(label: 'Save');
// #enddocregion control
''');
      final config = File('${directory.path}/metadata.json')
        ..writeAsStringSync(
          jsonEncode({
            'schemaVersion': 1,
            'components': {
              'control': {
                'library': 'components.dart',
                'symbols': ['Control'],
                'example': {'file': 'components.dart', 'region': 'control'},
              },
            },
          }),
        );
      final output = await generateMetadata(config);
      final components = output['components'] as Map<String, Object?>;
      final control = components['control'] as Map<String, Object?>;
      expect(control['apiDescription'], contains('A documented control.'));
      expect(
        control['apiDescription'],
        contains('`label`: `String` (required)'),
      );
      expect(control['apiDescription'], contains('default `false`'));
      expect(control['exampleCode'], "const sample = Control(label: 'Save');");
      expect(control['sourceFiles'], ['components.dart']);
      expect(await generateMetadata(config), output);
    },
  );
}
