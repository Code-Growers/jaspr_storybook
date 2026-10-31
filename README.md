# Jaspr Storybook

Render real Jaspr components in Storybook. This Dart package supplies component
builders and the browser runtime; the companion npm package
`@codegrowers/storybook-jaspr-vite` supplies the renderer and Vite integration.
Use `jaspr_storybook` `1.0.1` with the compatible npm framework `1.0.0`.

```sh
dart pub add --dev jaspr_storybook:^1.0.1
```

MIT licensed. [Framework source](https://github.com/Code-Growers/storybook-jaspr-vite) · [npm package](https://www.npmjs.com/package/@codegrowers/storybook-jaspr-vite).

## Register components

Add `jaspr_storybook` as a development dependency alongside Jaspr, then create
`lib/storybook.client.dart`:

```dart
import 'package:jaspr/dom.dart';
import 'package:jaspr_storybook/jaspr_storybook.dart';

void main() {
  registerStorybook({
    'button': (story) => button(
      disabled: story.arg<bool>('disabled'),
      onClick: () => story.action('onClick'),
      [.text(story.arg<String>('label'))],
    ),
  });
}
```

The companion framework compiles this entrypoint with the Dart SDK. Use standard
TypeScript CSF stories with `component: 'button'`, `args`, and `argTypes`.
Docs can show actual Dart builders selected with `#docregion` markers, with Dart
syntax highlighting. See [STORYBOOK.md](STORYBOOK.md) for complete setup and the self-contained
[example/main.dart](example/main.dart) for a working Dart entrypoint and
[example/README.md](example/README.md) for setup instructions. The companion
framework has its own repository.

## Runtime contract

- `story.arg<T>(name)` checks a required argument's type.
- `story.args` and `story.globals` expose JSON-compatible values. JavaScript
  functions, component objects and Dart closures are not argument values.
- `story.action(name, value)` records an Actions-panel event.
- `story.updateArgs(patch)` changes Storybook controls and rebuilds the preview.
- `story.instanceId` namespaces DOM ids for concurrent previews.
- Root updates preserve descendant state with stable component types and keys.
  Changing stories or forcing a remount creates fresh state.
- Call `Jaspr.initializeApp` with your generated options before registration if
  your components need custom initialization. Default initialization is otherwise
  automatic. Browser globals are only used by the client runtime.

CSS and fonts belong to the consumer. Import them in `.storybook/preview.ts` or
use Storybook static assets. This package includes no Electree code, styles,
assets, services or branding. It previews client-side components; it does not
run server-only components or verify SSR/hydration behavior.

## Development and release

Run `dart pub get`, `dart format .`, `dart analyze`, `dart test` and
`dart pub publish --dry-run` from this repository. See [STORYBOOK.md](STORYBOOK.md)
for the example setup and paired release process.
