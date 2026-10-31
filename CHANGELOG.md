# Changelog

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
