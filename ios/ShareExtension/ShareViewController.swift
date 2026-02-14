import MobileCoreServices
import Social
import UIKit

final class ShareViewController: SLComposeServiceViewController {
  private let appGroupSuite = "group.com.example.urlInbox"
  private let pendingKey = "pending_urls"

  override func isContentValid() -> Bool {
    true
  }

  override func didSelectPost() {
    collectSharedUrls { [weak self] urls in
      guard let self = self else { return }
      self.appendPending(urls: urls)
      self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
  }

  override func configurationItems() -> [Any]! {
    []
  }

  private func collectSharedUrls(completion: @escaping ([String]) -> Void) {
    guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
      completion([])
      return
    }

    var urls = [String]()
    let group = DispatchGroup()

    for item in items {
      let providers = item.attachments ?? []
      for provider in providers {
        if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
          group.enter()
          provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { item, _ in
            defer { group.leave() }
            if let url = item as? URL {
              urls.append(url.absoluteString)
            } else if let text = item as? String {
              urls.append(contentsOf: self.extractUrls(from: text))
            }
          }
        } else if provider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
          group.enter()
          provider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { item, _ in
            defer { group.leave() }
            if let text = item as? String {
              urls.append(contentsOf: self.extractUrls(from: text))
            }
          }
        }
      }
    }

    group.notify(queue: .main) {
      completion(Array(Set(urls.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })))
    }
  }

  private func extractUrls(from text: String) -> [String] {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
      return []
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return detector.matches(in: text, options: [], range: range)
      .compactMap { $0.url?.absoluteString }
  }

  private func appendPending(urls: [String]) {
    guard !urls.isEmpty else { return }
    let defaults = UserDefaults(suiteName: appGroupSuite) ?? UserDefaults.standard
    var current = defaults.stringArray(forKey: pendingKey) ?? []
    for url in urls where !current.contains(url) {
      current.append(url)
    }
    defaults.set(current, forKey: pendingKey)
  }
}
