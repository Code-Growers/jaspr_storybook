# Changelog

## 1.1.0-beta.1

- Add a VM-only metadata generator for resolved Dart APIs, constructor defaults, source mappings and marked examples.
- Include the installable jaspr-storybook-workflow skill for the Storybook 11 CLI.
- Document compatibility with npm framework 2.0.0-beta.0; browser protocol remains v1.

## 1.1.0-beta.0

- Require Jaspr 0.24.0-beta.0 or later in the 0.24 line and Dart 3.13.
  Jaspr 0.23 applications keep using 1.0.x.
- Mount every story through the shared `ClientAppBinding` singleton: one hidden
  root renders each story into a `display: contents` wrapper in its host through
  a `ChildSlot`, replacing the per-story binding subclass that Jaspr 0.24 no longer allows.
- Story builder errors still reject mounting and updates. Errors in nested
  components now render Jaspr's inline fallback and are logged to the console
  instead of reaching Storybook's error overlay.
- Remounting into the same host immediately after teardown renders a fresh tree.

## 1.0.1

- Provide the working Storybook demo at `example/main.dart` so pub.dev detects
  it and displays the Example tab.
- Add example setup instructions and update its Storybook entrypoint.

## 1.0.0

- Initial MIT-licensed release of the Jaspr Storybook integration.
- Render Jaspr components with controls, globals, actions and argument updates.
- Preserve component state on argument updates and isolate concurrent Docs previews.
- Dispose component trees on teardown and surface render errors in Storybook.
- Compile Dart through Vite for development and static Storybook builds.
- Display actual Dart source regions in Docs with Dart syntax highlighting.
