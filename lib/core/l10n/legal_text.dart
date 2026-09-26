/// The privacy policy and terms, as data rather than as markup.
///
/// Kept out of `app_strings.dart` only because of its size — the same rule
/// applies: no user-facing sentence is written inside a widget.
///
/// **These documents describe what the code actually does.** If you change
/// what is stored, what is sent, or what the app writes to someone's Telegram
/// account, change the matching section here in the same commit. A privacy
/// policy that has drifted from the code is worse than none, because people
/// have relied on it.
library;

class LegalSection {
  final String heading;
  final List<String> paragraphs;

  const LegalSection(this.heading, this.paragraphs);
}

class LegalDocument {
  final String title;

  /// Shown under the title, so a reader can tell how current this is.
  final String lastUpdated;

  /// One line, above the sections: what this document is for.
  final String summary;

  final List<LegalSection> sections;

  const LegalDocument({
    required this.title,
    required this.lastUpdated,
    required this.summary,
    required this.sections,
  });
}

abstract class LegalTexts {
  /// Where to write with a question about either document.
  static const String contactEmail = 'daveyeinde@gmail.com';

  static const String lastUpdated = '23 August 2026';

  static const privacyRoute = '/legal/privacy';
  static const termsRoute = '/legal/terms';

  static const LegalDocument privacy = LegalDocument(
    title: 'Privacy Policy',
    lastUpdated: lastUpdated,
    summary:
        'gramX has no servers of its own. Signed in or browsing as a guest, it '
        'talks to Telegram and to nobody else, and everything it keeps stays '
        'on your phone.',
    sections: [
      LegalSection('Who this is', [
        'gramX is an independent reader for Telegram channels, made by one '
            'person. It is not made by, affiliated with, or endorsed by '
            'Telegram.',
        'Questions about this policy: $contactEmail.',
      ]),
      LegalSection('Guest mode', [
        'You can read public channels without signing in. In that mode there '
            'is no Telegram account involved at all, and the app talks to '
            'Telegram over the ordinary web instead of through TDLib: for '
            'each channel you add, it fetches the public preview page at '
            'https://t.me/s/<channel> — the same page anyone can open in a '
            'browser — and reads the posts out of it.',
        'Those requests carry what a browser request carries: your IP address, '
            'a browser user-agent string, and your device\'s language setting. '
            'They go to Telegram and to nobody else. The pictures on those '
            'posts are downloaded from Telegram\'s own servers and cached on '
            'your phone.',
        'Guest mode is read-only. Nothing is sent on your behalf: no '
            'reactions, no comments, no read state, no subscriptions. There is '
            'no account for any of that to happen to.',
        'What is stored is the list of channels you added, and the pictures '
            'cached for them. Leaving guest mode deletes both.',
      ]),
      LegalSection('There is no gramX server', [
        'This app has no backend. When you sign in, the app connects straight '
            'to Telegram from your phone using TDLib, Telegram\'s own client '
            'library. Nothing you read, write or tap is sent to the developer '
            'or to any third party.',
        'That also means Telegram receives what it would receive from any '
            'Telegram client — your account activity, the channels you read, '
            'the messages you send. That part is covered by Telegram\'s own '
            'privacy policy, not by this one.',
      ]),
      LegalSection('What is stored on your phone', [
        'Telegram\'s local database of your chats, messages and downloaded '
            'media. It is encrypted with a 256-bit key held in your device\'s '
            'keystore, and it is what makes the app work offline.',
        'A record of the signed-in account — your Telegram user id, display '
            'name, username, phone number and the path to your avatar — so the '
            'app can show whose feed it is showing.',
        'Your bookmarks, as a list of chat and message ids. Each one also '
            'has a copy in your Telegram Saved Messages — see below — and '
            'that copy is what lets them survive reinstalling the app.',
        'Your preferences: theme, autoplay, and which channels you have muted '
            'along with when each mute expires.',
        'A short log of errors the app has caught — the last fifty, with '
            'phone numbers, file paths and keys stripped out before anything '
            'is written down. It is never shown to anyone and never sent '
            'anywhere; it exists so a bug you report can be looked into.',
        'None of this leaves the device.',
      ]),
      LegalSection('Keeping it safe', [
        'The local database is encrypted, and the key that opens it is held by '
            'your device\'s keystore rather than by the app. Someone with the '
            'files alone cannot read them.',
        'Nothing gramX stores is unique to it: everything is a copy of what is '
            'already in your Telegram account, so losing the phone loses '
            'nothing that ending the session from another device does not '
            'protect.',
      ]),
      LegalSection('What the app does to your Telegram account', [
        'This applies when you are signed in. In guest mode there is no '
            'account, so none of it happens.',
        'This is a real Telegram client, so reading here changes things there. '
            'Specifically, gramX will: mark posts as read once they have been '
            'on your screen long enough, and that read state syncs to every '
            'device you use Telegram on; send the reactions you tap; post the '
            'comments you write; forward the posts you forward; subscribe '
            'you to a channel when you add one; and forward a post into your '
            'Saved Messages when you bookmark it, deleting that copy again '
            'when you remove the bookmark.',
        'Read state cannot be undone. If you want the unread badges on your '
            'other devices left alone, do not read those posts here.',
        'Your gramX session appears in Telegram under Settings → Devices, '
            'where you can end it at any time.',
      ]),
      LegalSection('What the app never does', [
        'No analytics, no advertising, no tracking of any kind. There is no '
            'third-party SDK in the app that phones home.',
        'No crash reporting service. The app keeps its own error log on the '
            'device so you can be asked what went wrong, and there is nowhere '
            'for it to send that log even if it wanted to.',
        'Nothing is sold, shared or transmitted to anyone. There is nobody to '
            'transmit it to.',
        'Media and link previews are fetched through Telegram, never from '
            'other hosts — so reading a post does not tell the website behind '
            'a link that you looked at it.',
      ]),
      LegalSection('When you leave the app', [
        'Tapping a link in a post opens it in your browser. From that point '
            'you are on that website, and it can see your visit as any website '
            'you open would.',
        'If you turn notifications on, your device shows them. Telegram '
            'decides what is worth a notification — a chat you muted there '
            'stays quiet here — and the text comes from Telegram; gramX only '
            'draws it. Notifications are off until you turn them on.',
        'Settings has two links of its own — a way to support the work, and '
            'the source code. They open in your browser too.',
      ]),
      LegalSection('Deleting your data', [
        'Logging out signs the session out of Telegram and clears the local '
            'account record, your bookmarks, and Telegram\'s local database.',
        'Your preferences — theme, autoplay, muted channels — stay on the '
            'device until you uninstall the app.',
        'The error log is deleted with the app\'s data when you uninstall it.',
        'Settings → Media storage and cache clears downloaded media without '
            'signing you out.',
      ]),
      LegalSection('Age', [
        'You need a Telegram account to use gramX, so you must be old enough '
            'to have one where you live.',
      ]),
      LegalSection('Changes', [
        'If what the app stores or sends changes, this policy changes with it, '
            'and the date at the top moves. Continuing to use the app after '
            'that means the new version applies.',
      ]),
    ],
  );

  static const LegalDocument terms = LegalDocument(
    title: 'Terms of Service',
    lastUpdated: lastUpdated,
    summary:
        'An independent reader for Telegram channels, and the terms it comes '
        'with.',
    sections: [
      LegalSection('What you are agreeing to', [
        'By using gramX you accept these terms. If you do not, do not sign in.',
        'gramX is an independent app for reading Telegram channels. It is not '
            'made by, affiliated with, or endorsed by Telegram.',
      ]),
      LegalSection('You bring your own Telegram account', [
        'gramX does not create accounts. It signs into the Telegram account '
            'you already have, and everything you do through it is also '
            'governed by Telegram\'s Terms of Service and their rules about '
            'what may be posted and shared.',
        'You are responsible for what you send, react to, forward and post '
            'through this app, exactly as if you had done it in Telegram.',
      ]),
      LegalSection('The app is provided as it is', [
        'gramX comes with no warranty of any kind. Software has faults, and '
            'this app depends on a service it does not control: it may show '
            'the wrong thing, stop working, or change as Telegram changes.',
        'To the extent the law allows, the developer is not liable for any '
            'loss arising from using it — including lost read state, missed '
            'posts, or anything that follows from a fault.',
        'Features may change or be removed between versions.',
      ]),
      LegalSection('Your account\'s standing with Telegram', [
        'Telegram rate-limits accounts that make too many requests. gramX '
            'throttles itself deliberately to stay well inside those limits, '
            'but no client can guarantee it: heavy use can still earn a '
            'temporary wait imposed by Telegram on your account, not on this '
            'app.',
        'Do not use gramX to break Telegram\'s rules, to scrape at scale, or '
            'to do anything unlawful where you live.',
      ]),
      LegalSection('Whose content this is', [
        'Posts shown in gramX belong to the channels that published them. The '
            'app displays what your account can already see and claims no '
            'rights over it.',
      ]),
      LegalSection('Stopping', [
        'Log out from Settings at any time, or end the session from Telegram '
            'under Settings → Devices. Uninstalling removes everything the app '
            'kept on your phone.',
      ]),
      LegalSection('Questions', [
        'Write to $contactEmail.',
      ]),
    ],
  );

  /// The document behind a route parameter, or null if it isn't one of them.
  static LegalDocument? byId(String id) => switch (id) {
        'privacy' => privacy,
        'terms' => terms,
        _ => null,
      };
}
