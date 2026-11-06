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
  final _mounted = ValueNotifier<List<_Session>>(const []);
  bool _attached = false;

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
    final container = web.document.createElement('div') as web.HTMLElement
      ..setAttribute('data-jaspr-story', instanceId)
      ..style.display = 'contents';
    target.appendChild(container);
    final session = _Session(
      storyId: storyId,
      instanceId: instanceId,
      builder: builder,
      container: container,
      args: _decodeRecord(args),
      globals: _decodeRecord(globals),
      emit: emit,
    );
    sessions[instanceId] = session;
    _mounted.value = [..._mounted.value, session];
    _attachHub();
    try {
      await Future<void>.microtask(() {});
      session.throwBuildError();
      session.rendering = false;
    } catch (_) {
      unmount(instance);
      rethrow;
    }
    return null;
  }

  void _attachHub() {
    if (_attached) return;
    _attached = true;
    final root = web.document.createElement('div') as web.HTMLElement
      ..id = _hubRootId
      ..hidden = true.toJS;
    web.document.body!.appendChild(root);
    ClientAppBinding.ensureInitialized().attachRootComponent(
      _StoryHub(_mounted),
      attachTo: '#$_hubRootId',
    );
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
    session.rebuild = null;
    _mounted.value = [
      for (final mounted in _mounted.value)
        if (mounted != session) mounted,
    ];
    Future<void>.microtask(() => session.container.remove());
  }
}

const _hubRootId = 'jaspr-storybook-root';

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
    required this.container,
    required this.args,
    required this.globals,
    required this.emit,
  });

  final String storyId;
  final String instanceId;
  final StorybookBuilder builder;
  final web.HTMLElement container;
  final JSFunction emit;
  Map<String, Object?> args;
  Map<String, Object?> globals;
  void Function()? rebuild;
  bool disposed = false;
  bool rendering = true;
  (Object, StackTrace)? buildError;

  void send(String type, Object? payload) {
    if (!disposed) {
      emit.callAsFunction(null, type.toJS, payload.jsify());
    }
  }

  void reportBuildError(Object error, StackTrace stackTrace) {
    buildError = (error, stackTrace);
    if (!rendering) {
      send('error', {
        'message': error.toString(),
        'stack': stackTrace.toString(),
      });
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

class _StoryHub extends StatelessComponent {
  const _StoryHub(this.mounted);
  final ValueListenable<List<_Session>> mounted;

  @override
  Component build(BuildContext context) => ListenableBuilder(
    listenable: mounted,
    builder: (context) => SlottedChildView(
      slots: [
        for (final session in mounted.value)
          _StorySlot(
            session.container,
            key: ValueKey(session),
            child: _StoryRoot(session),
          ),
      ],
    ),
  );
}

class _StorySlot extends ChildSlot {
  const _StorySlot(this.container, {required this.child, super.key});

  final web.HTMLElement container;
  @override
  final Component child;

  @override
  ChildSlotRenderObject createRenderObject(SlottedDomRenderObject parent) =>
      ChildSlotRenderObject(container, parent);

  @override
  bool canUpdate(ChildSlot oldComponent) =>
      oldComponent is _StorySlot && oldComponent.container == container;
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
  Component build(BuildContext context) {
    final session = component.session;
    try {
      return session.builder(session.context);
    } catch (error, stackTrace) {
      session.reportBuildError(error, stackTrace);
      return const Component.fragment([]);
    }
  }
}
