import Social
import UIKit
import UniformTypeIdentifiers

/// "Share to Hoopla": saves a reel link from Instagram, TikTok or YouTube for the next party.
/// The Hoopla app picks it up from the shared App Group the next time it opens.
class ShareViewController: SLComposeServiceViewController {
  static let appGroup = "group.com.northbitapps.hoopla"
  private var sharedURL: String?

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Save to Hoopla"
    placeholder = "Name this game (optional)"
    let sharedText = contentText
    textView.text = ""
    findURL(fallbackText: sharedText)
  }

  override func presentationAnimationDidFinish() {
    super.presentationAnimationDidFinish()
    navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = "Save"
  }

  override func isContentValid() -> Bool {
    return sharedURL != nil
  }

  override func configurationItems() -> [Any]! {
    return []
  }

  override func didSelectPost() {
    if let url = sharedURL {
      let defaults = UserDefaults(suiteName: Self.appGroup)
      var items = defaults?.array(forKey: "pendingReels") as? [[String: String]] ?? []
      let name = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
      items.append(["url": url, "title": name])
      defaults?.set(items, forKey: "pendingReels")
    }
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  private func findURL(fallbackText: String?) {
    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    let providers = items.flatMap { $0.attachments ?? [] }
    let urlType = UTType.url.identifier
    let textType = UTType.plainText.identifier

    if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
      provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] item, _ in
        let url = (item as? URL)?.absoluteString ?? (item as? String).flatMap { Self.firstLink(in: $0) }
        DispatchQueue.main.async { self?.setURL(url ?? Self.firstLink(in: fallbackText)) }
      }
    } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) {
      provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] item, _ in
        let url = Self.firstLink(in: item as? String)
        DispatchQueue.main.async { self?.setURL(url ?? Self.firstLink(in: fallbackText)) }
      }
    } else {
      setURL(Self.firstLink(in: fallbackText))
    }
  }

  private func setURL(_ url: String?) {
    sharedURL = url
    validateContent()
  }

  static func firstLink(in text: String?) -> String? {
    guard let text = text,
      let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    return detector.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
  }
}
