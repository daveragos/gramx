/// Every address this app can send someone to on purpose.
///
/// Kept together and kept short deliberately: these are the only outbound
/// destinations the app itself offers — everything else it opens came from a
/// post the reader tapped. The privacy policy says as much, so a new entry
/// here means a line there too.
abstract class AppLinks {
  /// Where the developer can be supported.
  static const String support = 'https://gurshaplus.com/ragoose';

  /// This app's source.
  static const String repository = 'https://github.com/daveragos/gramx';

  /// The person who made it.
  static const String developer = 'https://github.com/daveragos';
}
