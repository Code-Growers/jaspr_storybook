import 'context.dart';

/// Registers the client-side component builders exposed to Storybook.
///
/// Call this in the Dart entrypoint configured in `@codegrowers/storybook-jaspr-vite`.
void registerStorybook(Map<String, StorybookBuilder> stories) {
  throw UnsupportedError('Storybook previews must run in a web browser.');
}
