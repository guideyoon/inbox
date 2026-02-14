import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "url_inbox/share"
  private let pendingKey = "pending_urls"
  private let appGroupSuite = "group.com.example.urlInbox"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let completed = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    setupShareChannel()

    if let launchUrl = launchOptions?[.url] as? URL {
      appendPending(urls: [launchUrl.absoluteString])
    }

    return completed
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    appendPending(urls: [url.absoluteString])
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      appendPending(urls: [url.absoluteString])
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  private func setupShareChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result("[]")
        return
      }
      if call.method == "consumeSharedUrls" {
        result(self.consumePendingJson())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func appendPending(urls: [String]) {
    let existing = consumePending(clear: false)
    var merged = existing
    urls.forEach { url in
      if !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !merged.contains(url) {
        merged.append(url)
      }
    }
    userDefaults().set(merged, forKey: pendingKey)
  }

  private func consumePendingJson() -> String {
    let urls = consumePending()
    let list = urls.map { ["url": $0, "title": ""] }
    guard let data = try? JSONSerialization.data(withJSONObject: list, options: []) else {
      return "[]"
    }
    return String(data: data, encoding: .utf8) ?? "[]"
  }

  private func consumePending(clear: Bool = true) -> [String] {
    let defaults = userDefaults()
    let current = defaults.stringArray(forKey: pendingKey) ?? []
    if clear {
      defaults.removeObject(forKey: pendingKey)
    }
    return current
  }

  private func userDefaults() -> UserDefaults {
    UserDefaults(suiteName: appGroupSuite) ?? UserDefaults.standard
  }
}
