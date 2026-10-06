import UIKit
import UniformTypeIdentifiers

/// "gramX" in the share sheet. It has no screen of its own: it opens gramX
/// with what was shared, as `gramx://share?text=…`, and the app decides
/// what to do with it. A link carries the text, so no app group is needed.
class ShareViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    Task { @MainActor in
      if let text = await sharedText(), let url = Self.appURL(for: text) {
        open(url)
      }
      extensionContext?.completeRequest(returningItems: nil)
    }
  }

  /// The first web link shared, or else the first text. A page shared from
  /// a browser comes as its link.
  private func sharedText() async -> String? {
    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    let providers = items.flatMap { $0.attachments ?? [] }

    for provider in providers
    where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
      let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
      if let url = item as? URL, !url.isFileURL { return url.absoluteString }
    }
    for provider in providers
    where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
      if let text = item as? String { return text }
      if let data = item as? Data { return String(data: data, encoding: .utf8) }
    }
    return nil
  }

  /// `gramx://share?text=…`, with `+`, `&` and `=` escaped too, since Dart
  /// reads a `+` in a query as a space.
  static func appURL(for text: String) -> URL? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))
    guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) else {
      return nil
    }
    return URL(string: "gramx://share?text=\(encoded)")
  }

  /// Opens gramX. Extensions may not call UIApplication's open, so this
  /// finds the application on the responder chain and sends the message
  /// through the Objective-C runtime.
  private func open(_ url: URL) {
    typealias OpenURL = @convention(c) (
      AnyObject, Selector, NSURL, NSDictionary, (@convention(block) (Bool) -> Void)?
    ) -> Void
    let selector = NSSelectorFromString("openURL:options:completionHandler:")

    var responder: UIResponder? = self
    while let current = responder {
      if current is UIApplication, current.responds(to: selector) {
        let function = unsafeBitCast(current.method(for: selector), to: OpenURL.self)
        function(current, selector, url as NSURL, NSDictionary(), nil)
        return
      }
      responder = current.next
    }
  }
}
