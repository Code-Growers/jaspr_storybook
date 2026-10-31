import 'package:jaspr_storybook/jaspr_storybook.dart';
import 'package:test/test.dart';

void main() {
  test('checks input types and forwards controlled state and actions', () {
    final actions = <(String, Object?)>[];
    final patches = <Map<String, Object?>>[];
    final input = <String, Object?>{'label': 'Save', 'disabled': false};
    final context = StorybookContext(
      storyId: 'button',
      instanceId: 'preview-1',
      args: input,
      globals: const {'locale': 'en'},
      onAction: (name, value) => actions.add((name, value)),
      onUpdateArgs: patches.add,
    );

    input['label'] = 'Changed outside context';
    expect(context.arg<String>('label'), 'Save');
    expect(context.arg<bool>('disabled'), isFalse);
    expect(() => context.arg<int>('label'), throwsArgumentError);
    expect(() => context.arg<String>('missing'), throwsArgumentError);
    expect(() => context.args['label'] = 'Mutation', throwsUnsupportedError);

    context.action('onClick', 'Save');
    context.updateArgs({'disabled': true});
    expect(actions, [('onClick', 'Save')]);
    expect(patches, [
      {'disabled': true},
    ]);
  });

  test('browser registration fails explicitly on a Dart VM', () {
    expect(() => registerStorybook({}), throwsUnsupportedError);
  });
}
