import Carbon
import Cocoa
import FlutterMacOS

/// macOS implementation of keyboard_language, built on the Text Input Sources
/// API: reads `TISCopyCurrentKeyboardInputSource`, observes the distributed
/// notification `kTISNotifySelectedKeyboardInputSourceChanged`, lists
/// select-capable keyboard input sources and selects one with
/// `TISSelectInputSource`.
public class KeyboardLanguagePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var observer: NSObjectProtocol?
  private var lastSent: NSDictionary?
  private var hasSent = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = KeyboardLanguagePlugin()
    let channel = FlutterMethodChannel(
      name: "dev.manishpanday/keyboard_language",
      binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: channel)
    let events = FlutterEventChannel(
      name: "dev.manishpanday/keyboard_language/events",
      binaryMessenger: registrar.messenger)
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCurrent":
      result(currentPayload() ?? NSNull())
    case "getAvailable":
      result(selectableSources().compactMap { payload(for: $0) })
    case "setLanguage":
      guard let args = call.arguments as? [String: Any],
        let tag = args["languageTag"] as? String, !tag.isEmpty
      else {
        result(
          FlutterError(code: "bad_args", message: "languageTag is required", details: nil))
        return
      }
      result(select(languageTag: tag))
    case "getCapabilities":
      result([
        "canReadCurrent": true,
        "canObserveChanges": true,
        "canListAvailable": true,
        "canSetLanguage": true,
        "requiresFocusedTextField": false,
        "isWeakHint": false,
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Text Input Sources helpers

  private func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
  }

  private func languages(of source: TISInputSource) -> [String] {
    let list: [String]? = property(source, kTISPropertyInputSourceLanguages)
    return list ?? []
  }

  private func payload(for source: TISInputSource) -> [String: Any]? {
    guard let language = languages(of: source).first, !language.isEmpty else { return nil }
    var map: [String: Any] = [
      "languageTag": language,
      "source": "keyboardLayout",
    ]
    if let id: String = property(source, kTISPropertyInputSourceID) {
      map["inputSourceId"] = id
    }
    if let name: String = property(source, kTISPropertyLocalizedName) {
      map["displayName"] = name
    }
    return map
  }

  private func currentPayload() -> [String: Any]? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
      return nil
    }
    return payload(for: source)
  }

  private func selectableSources() -> [TISInputSource] {
    let filter: [CFString: Any] = [
      kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
      kTISPropertyInputSourceIsSelectCapable: true,
    ]
    guard
      let list = TISCreateInputSourceList(filter as CFDictionary, false)?
        .takeRetainedValue() as? [TISInputSource]
    else { return [] }
    return list
  }

  private static func normalize(_ tag: String) -> String {
    tag.replacingOccurrences(of: "_", with: "-").lowercased()
  }

  /// Selects the first enabled keyboard input source whose primary language
  /// equals `languageTag`, else the first whose primary language subtag
  /// matches. Returns false when none matches or selection fails.
  private func select(languageTag: String) -> Bool {
    let wanted = KeyboardLanguagePlugin.normalize(languageTag)
    let wantedPrimary = wanted.split(separator: "-").first.map(String.init) ?? wanted
    let sources = selectableSources()
    let exact = sources.first { source in
      languages(of: source).first.map(KeyboardLanguagePlugin.normalize) == wanted
    }
    let candidate =
      exact
      ?? sources.first { source in
        guard let primary = languages(of: source).first else { return false }
        let normalized = KeyboardLanguagePlugin.normalize(primary)
        return normalized.split(separator: "-").first.map(String.init) == wantedPrimary
      }
    guard let source = candidate else { return false }
    let status = TISSelectInputSource(source)
    if status == noErr {
      DispatchQueue.main.async { [weak self] in self?.emitIfChanged() }
      return true
    }
    return false
  }

  // MARK: - Observing

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    hasSent = false
    lastSent = nil
    if observer == nil {
      observer = DistributedNotificationCenter.default().addObserver(
        forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emitIfChanged()
      }
    }
    emitIfChanged()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = observer {
      DistributedNotificationCenter.default().removeObserver(observer)
    }
    observer = nil
    eventSink = nil
    return nil
  }

  private func emitIfChanged() {
    guard let sink = eventSink else { return }
    let current = currentPayload().map { NSDictionary(dictionary: $0) }
    if hasSent && current == lastSent { return }
    hasSent = true
    lastSent = current
    sink(current ?? NSNull())
  }
}
