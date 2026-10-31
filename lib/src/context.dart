import 'package:jaspr/jaspr.dart';

/// Builds a component from the current Storybook arguments and globals.
typedef StorybookBuilder = Component Function(StorybookContext context);

/// The current inputs and event channel for one mounted story instance.
///
/// Use [instanceId] to namespace DOM ids when multiple stories appear in Docs.
/// The renderer rebuilds the root when arguments or globals change, preserving
/// state in descendants with stable component types and keys.
class StorybookContext {
  /// Creates a story context. Applications normally receive one in a builder.
  StorybookContext({
    required this.storyId,
    required this.instanceId,
    required Map<String, Object?> args,
    required Map<String, Object?> globals,
    required void Function(String name, Object? value) onAction,
    required void Function(Map<String, Object?> patch) onUpdateArgs,
  }) : args = Map.unmodifiable(args),
       globals = Map.unmodifiable(globals),
       _onAction = onAction,
       _onUpdateArgs = onUpdateArgs;

  /// The key registered with [registerStorybook].
  final String storyId;

  /// A unique identifier for this mounted preview, including inline Docs.
  final String instanceId;

  /// JSON-compatible Storybook controls values.
  final Map<String, Object?> args;

  /// JSON-compatible values from Storybook's toolbar and global configuration.
  final Map<String, Object?> globals;

  final void Function(String name, Object? value) _onAction;
  final void Function(Map<String, Object?> patch) _onUpdateArgs;

  /// Reads a required argument and checks its type.
  T arg<T>(String name) {
    final value = args[name];
    if (value is! T) {
      throw ArgumentError.value(value, name, 'Expected an argument of type $T');
    }
    return value;
  }

  /// Records an event in Storybook's Actions panel.
  void action(String name, [Object? value]) => _onAction(name, value);

  /// Updates controls, for example after toggling a controlled switch.
  void updateArgs(Map<String, Object?> patch) => _onUpdateArgs(patch);
}
