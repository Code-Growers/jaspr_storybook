import 'dart:async';
import 'dart:js_interop';

import 'package:jaspr/client.dart';
import 'package:web/web.dart' as web;

import 'context.dart';

@JS('__jasprStorybook')
external set _bridge(_Bridge value);

@JS()
extension type _Bridge._(JSObject _) implements JSObject {
  external factory _Bridge({
    required JSNumber protocolVersion,
    required JSFunction mount,
    required JSFunction update,
    required JSFunction unmount,
  });
}

@JS('Error')
extension type _JavaScriptError._(JSObject _) implements JSObject {
  external _JavaScriptError(JSString message);
  external set stack(JSString value);
}

// Future.toJS boxes Dart errors with a generic message. Storybook needs a real
// JavaScript Error containing the builder's message for its error UI.
JSPromise<JSAny?> _promise(Future<JSAny?> future) => JSPromise<JSAny?>(
  (JSFunction resolve, JSFunction reject) {
    future.then<void>(
      (value) => resolve.callAsFunction(null, value),
      onError: (Object error, StackTrace stack) {
        final message = error.toString();
        final wrapped = _JavaScriptError(message.toJS)
          ..stack = '$message\n$stack'.toJS;
        reject.callAsFunction(null, wrapped);
      },
    );
  }.toJS,
);

/// Registers client-side builders for the companion Storybook renderer.
///
/// Keys correspond to the `component` field in TypeScript story metadata.
/// Initialize Jaspr with generated options before this call if your components
/// require custom Jaspr initialization. Otherwise default options are used.
void registerStorybook(Map<String, StorybookBuilder> stories) {
  if (stories.isEmpty || stories.keys.any((key) => key.trim().isEmpty)) {
    throw ArgumentError('Provide at least one builder with a nonempty key.');
  }
  if (!Jaspr.isInitialized) {
    Jaspr.initializeApp();
  }
  final runtime = _Runtime(Map.unmodifiable(stories));
  _bridge = _Bridge(
    protocolVersion: 1.toJS,
    mount: runtime.mount.toJS,
    update: runtime.update.toJS,
    unmount: runtime.unmount.toJS,
  );
}

class _Runtime {
  _Runtime(this.builders);

  final Map<String, StorybookBuilder> builders;
  final sessions = <String, _Session>{};

  JSPromise<JSAny?> mount(
    JSString instance,
    JSString story,
    JSString host,
    JSAny? args,
    JSAny? globals,
    JSFunction emit,
  ) => _promise(_mount(instance, story, host, args, globals, emit));

  Future<JSAny?> _mount(
    JSString instance,
    JSString story,
    JSString host,
    JSAny? args,
    JSAny? globals,
    JSFunction emit,
  ) async {
    final instanceId = instance.toDart;
    final storyId = story.toDart;
    final builder = builders[storyId];
    if (builder == null) {
      throw ArgumentError('No Jaspr builder registered for "$storyId".');
    }
    if (sessions.containsKey(instanceId)) {
      throw StateError('Story instance "$instanceId" is already mounted.');
    }
    final hostId = host.toDart;
    final target = web.document.getElementById(hostId);
    if (target == null) {
      throw StateError('Story host "$hostId" is not attached to the document.');
    }
    final session = _Session(
      storyId: storyId,
      instanceId: instanceId,
      builder: builder,
      args: _decodeRecord(args),
      globals: _decodeRecord(globals),
      emit: emit,
    );
    sessions[instanceId] = session;
    final binding = _StoryBinding(session);
    session.binding = binding;
    try {
      binding.attachRootComponent(
        _StoryRoot(session),
        attachTo: '#${web.CSS.escape(hostId)}',
      );
      await Future<void>.microtask(() {});
      session.throwBuildError();
      session.rendering = false;
    } catch (_) {
      unmount(instance);
      rethrow;
    }
    return null;
  }

  JSPromise<JSAny?> update(JSString instance, JSAny? args, JSAny? globals) =>
      _promise(_update(instance, args, globals));

  Future<JSAny?> _update(JSString instance, JSAny? args, JSAny? globals) async {
    final session = sessions[instance.toDart];
    if (session == null || session.disposed) {
      throw StateError('Cannot update an unmounted Jaspr story.');
    }
    session.buildError = null;
    session.rendering = true;
    session.args = _decodeRecord(args);
    session.globals = _decodeRecord(globals);
    session.rebuild!();
    await Future<void>.microtask(() {});
    session.rendering = false;
    session.throwBuildError();
    return null;
  }

  void unmount(JSString instance) {
    final session = sessions.remove(instance.toDart);
    if (session == null) return;
    session.disposed = true;
    session.binding?.detachRootComponent();
    session.rebuild = null;
  }
}

Map<String, Object?> _decodeRecord(JSAny? value) {
  final decoded = value.dartify();
  if (decoded is! Map<Object?, Object?>) {
    throw ArgumentError('Storybook arguments and globals must be objects.');
  }
  return decoded.map((key, value) => MapEntry(key as String, value));
}

class _Session {
  _Session({
    required this.storyId,
    required this.instanceId,
    required this.builder,
    required this.args,
    required this.globals,
    required this.emit,
  });

  final String storyId;
  final String instanceId;
  final StorybookBuilder builder;
  final JSFunction emit;
  Map<String, Object?> args;
  Map<String, Object?> globals;
  _StoryBinding? binding;
  void Function()? rebuild;
  bool disposed = false;
  bool rendering = true;
  (Object, StackTrace)? buildError;

  void send(String type, Object? payload) {
    if (!disposed) {
      emit.callAsFunction(null, type.toJS, payload.jsify());
    }
  }

  void throwBuildError() {
    if (buildError case (final error, final stack)) {
      Error.throwWithStackTrace(error, stack);
    }
  }

  StorybookContext get context => StorybookContext(
    storyId: storyId,
    instanceId: instanceId,
    args: args,
    globals: globals,
    onAction: (name, value) => send('action', {'name': name, 'value': value}),
    onUpdateArgs: (patch) => send('args', patch),
  );
}

class _StoryBinding extends ClientAppBinding {
  _StoryBinding(this.session);
  final _Session session;

  @override
  void reportBuildError(Element element, Object error, StackTrace stackTrace) {
    session.buildError = (error, stackTrace);
    if (!session.rendering) {
      session.send('error', {
        'message': error.toString(),
        'stack': stackTrace.toString(),
      });
    }
  }
}

class _StoryRoot extends StatefulComponent {
  const _StoryRoot(this.session);
  final _Session session;

  @override
  State<_StoryRoot> createState() => _StoryRootState();
}

class _StoryRootState extends State<_StoryRoot> {
  @override
  void initState() {
    super.initState();
    component.session.rebuild = () => setState(() {});
  }

  @override
  Component build(BuildContext context) =>
      component.session.builder(component.session.context);
}
