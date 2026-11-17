/// Headless Dart API extraction. Do not import this library in browser code.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

/// Generates schema-v1 metadata from explicit component/library/symbol mappings.
/// All input paths are relative to the configuration's [root] directory, which
/// itself is relative to the configuration file. Output paths share that root.
Future<Map<String, Object?>> generateMetadata(File config) async {
  final input = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  if (input['schemaVersion'] != 1) {
    throw FormatException('Expected schemaVersion 1');
  }
  final root = p.normalize(
    p.join(p.dirname(config.absolute.path), input['root'] as String? ?? '.'),
  );
  final collection = AnalysisContextCollection(includedPaths: [root]);
  final libraries = <String, LibraryElement>{};
  final components = <String, Object?>{};
  try {
    for (final entry in (input['components'] as Map<String, dynamic>).entries) {
      final spec = entry.value as Map<String, dynamic>;
      final libraryPath = p.normalize(p.join(root, spec['library'] as String));
      var library = libraries[libraryPath];
      if (library == null) {
        final result = await collection
            .contextFor(libraryPath)
            .currentSession
            .getResolvedLibrary(libraryPath);
        if (result is! ResolvedLibraryResult) {
          throw StateError('Cannot resolve $libraryPath');
        }
        library = result.element;
        libraries[libraryPath] = library;
      }
      final symbols = (spec['symbols'] as List<dynamic>).cast<String>();
      if (symbols.isEmpty) throw FormatException('No symbols for ${entry.key}');
      final sections = <String>[];
      final sources = <String>{};
      for (final name in symbols) {
        final element = library.exportNamespace.get2(name);
        if (element == null) {
          throw StateError('No exported component $name in $libraryPath');
        }
        final source = element.firstFragment.libraryFragment?.source.fullName;
        if (source != null) sources.add(p.relative(source, from: root));
        final constructors = element is InterfaceElement
            ? element.constructors.where((c) => c.isPublic)
            : <ConstructorElement>[];
        sections.add(
          '## $name\n\n${_documentation(element.documentationComment)}\n\n${constructors.isEmpty ? '```dart\n${element.displayString()}\n```' : constructors.map((c) => '```dart\n${c.displayString()}\n```').join('\n\n')}',
        );
        for (final constructor in constructors) {
          final parameters = constructor.formalParameters;
          if (parameters.isEmpty) continue;
          sections.add(
            '### ${constructor.displayName} parameters\n\n${parameters.map((parameter) => '- `${parameter.name}`: `${parameter.type.getDisplayString()}`${parameter.isRequired ? ' (required)' : ''}${parameter.defaultValueCode == null ? '' : '; default `${parameter.defaultValueCode}`'}. ${_documentation(parameter.documentationComment)}').join('\n')}',
          );
        }
      }
      final example = spec['example'] as Map<String, dynamic>?;
      String? exampleCode;
      if (example != null) {
        final file = p.normalize(p.join(root, example['file'] as String));
        sources.add(p.relative(file, from: root));
        final regions = _regions(File(file).readAsStringSync(), file);
        final names = [
          ...?example['supportRegions'] as List<dynamic>?,
          example['region'] as String,
        ];
        exampleCode = names
            .map(
              (name) =>
                  regions[name] ??
                  (throw StateError('Missing region $name in $file')),
            )
            .join('\n\n');
      }
      components[entry.key] = {
        'name': spec['name'] ?? symbols.first,
        if (spec['description'] != null) 'description': spec['description'],
        'apiDescription': [
          if (spec['contract'] != null) spec['contract'],
          ...sections,
        ].join('\n\n').trim(),
        if (spec['import'] != null) 'import': spec['import'],
        'sourceFiles': sources.toList()..sort(),
        'exampleCode': ?exampleCode,
      };
    }
  } finally {
    await collection.dispose();
  }
  return {
    'schemaVersion': 1,
    'root': p.relative(root, from: p.dirname(config.absolute.path)),
    'components': components,
  };
}

String _documentation(String? comment) => (comment ?? '')
    .split('\n')
    .map((line) => line.replaceFirst(RegExp(r'^\s*/// ?'), ''))
    .join('\n')
    .trim();

Map<String, String> _regions(String source, String file) {
  final result = <String, String>{};
  String? current;
  var lines = <String>[];
  for (final line in source.split('\n')) {
    final marker = RegExp(r'^\s*//\s*#(end)?docregion\s+(\S+)\s*$')
        .firstMatch(line);
    if (marker == null) {
      if (current != null) lines.add(line);
    } else if (marker[1] == null) {
      if (current != null || result.containsKey(marker[2])) {
        throw FormatException('Duplicate/nested source region in $file');
      }
      current = marker[2];
      lines = [];
    } else {
      if (current != marker[2]) {
        throw FormatException('Unmatched source region in $file');
      }
      final nonempty = lines.where((line) => line.trim().isNotEmpty);
      if (nonempty.isEmpty) {
        throw FormatException('Empty source region in $file');
      }
      final indent = nonempty
          .map((line) => line.length - line.trimLeft().length)
          .reduce((a, b) => a < b ? a : b);
      result[current!] = lines
          .map((line) => line.length < indent ? '' : line.substring(indent))
          .join('\n')
          .trim();
      current = null;
    }
  }
  if (current != null) throw FormatException('Unclosed source region in $file');
  return result;
}
