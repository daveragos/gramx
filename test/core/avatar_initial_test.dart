import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/widgets/channel_avatar.dart';

/// `title[0]` is one UTF-16 code unit, which is only half of an emoji.
void main() {
  test('a plain name draws its first letter, upper-cased', () {
    expect(ChannelAvatar.initialOf('ada lovelace'), 'A');
  });

  test('decoration in front of a name is skipped to the first letter', () {
    expect(ChannelAvatar.initialOf('🇮🇱🇮🇱🇮🇱 Israel Rulez 🇮🇱'), 'I');
    expect(ChannelAvatar.initialOf('⭐️ Stars'), 'S');
  });

  test('a script without case keeps its letter', () {
    expect(ChannelAvatar.initialOf('ሰላም'), 'ሰ');
    expect(ChannelAvatar.initialOf('Юрий'), 'Ю');
  });

  test('a name that is only emoji draws the whole first one', () {
    expect(ChannelAvatar.initialOf('👽👽'), '👽');
  });

  test('an empty name falls back to a question mark', () {
    expect(ChannelAvatar.initialOf('   '), '?');
  });
}
