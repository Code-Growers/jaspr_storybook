# Jaspr Storybook example

This example uses the local `jaspr_storybook` Dart package with the published
`@codegrowers/storybook-jaspr-vite` framework. It includes a button with editable
arguments and Actions, a controlled switch that updates Storybook Controls, and
stateful counters with independent component lifecycles.

From this directory, with the Dart SDK and Bun installed:

```sh
dart pub get
bun install
bun run dev
```

Open http://127.0.0.1:6006. The framework compiles [main.dart](main.dart) and
mounts the registered Jaspr components in the browser. This entrypoint runs in
the Storybook preview; launch it with `bun run dev`.

The TypeScript CSF files in `stories/` select Dart registry keys and define
their arguments, controls, variants and play functions. Configuration and preview
styles live in `storybook/`. The marked Dart source regions in `main.dart` appear
in the Docs code panels.

To build a static site:

```sh
bun run build
```

The output is `../storybook-static/` and can be served by any static web server.
