import Flutter
import UIKit

/// iOS implementation of keyboard_language.
///
/// iOS exposes the keyboard language only as `UITextInputMode.primaryLanguage`
/// of the *first responder*. While a Flutter text field is being edited, the
/// first responder is the engine's hidden text input view, so the value is only
/// reliable while a text field has focus; otherwise `getCurrent` returns nil.
/// Apps cannot switch the keyboard on iOS (no public API), so `setLanguage`
/// reports `unsupported`.
public class KeyboardLanguagePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var observers: [NSObjectProtocol] = []
  private var lastSent: NSDictionary?
  private var hasSent = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = KeyboardLanguagePlugin()
    let channel = FlutterMethodChannel(
      name: "dev.manishpanday/keyboard_language",
      binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    let events = FlutterEventChannel(
      name: "dev.manishpanday/keyboard_language/events",
      binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCurrent":
      result(currentPayload() ?? NSNull())
    case "getAvailable":
      result(UITextInputMode.activeInputModes.compactMap { payload(for: $0) })
    case "setLanguage":
      result(
        FlutterError(
          code: "unsupported",
          message: "iOS does not allow apps to change the user's keyboard language.",
          details: nil))
    case "getCapabilities":
      result([
        "canReadCurrent": true,
        "canObserveChanges": true,
        "canListAvailable": true,
        "canSetLanguage": false,
        "requiresFocusedTextField": true,
        "isWeakHint": false,
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Reading

  private func payload(for mode: UITextInputMode) -> [String: Any]? {
    guard let language = mode.primaryLanguage, !language.isEmpty,
      language != "emoji", language != "dictation"
    else { return nil }
    var map: [String: Any] = [
      "languageTag": language,
      "inputSourceId": language,
      "source": "inputMethod",
    ]
    if let name = Locale.current.localizedString(forIdentifier: language) {
      map["displayName"] = name
    }
    return map
  }

  private func currentPayload() -> [String: Any]? {
    guard let responder = FirstResponderFinder.find(), let mode = responder.textInputMode
    else { return nil }
    return payload(for: mode)
  }

  // MARK: - Observing

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    hasSent = false
    lastSent = nil
    let center = NotificationCenter.default
    let names: [Notification.Name] = [
      UITextInputMode.currentInputModeDidChangeNotification,
      UIResponder.keyboardDidShowNotification,
      UIResponder.keyboardDidHideNotification,
      UIApplication.didBecomeActiveNotification,
    ]
    for name in names {
      observers.append(
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          // The first responder's input mode is updated after the
          // notification is posted; read it on the next run-loop turn.
          DispatchQueue.main.async { self?.emitIfChanged() }
        })
    }
    emitIfChanged()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
    observers.removeAll()
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

/// Finds the current first responder by sending an action to the nil target,
/// which UIKit delivers to the first responder, with a view-hierarchy search as
/// a fallback.
enum FirstResponderFinder {
  fileprivate static weak var captured: UIResponder?

  static func find() -> UIResponder? {
    captured = nil
    UIApplication.shared.sendAction(
      #selector(UIResponder.keyboardLanguage_captureFirstResponder(_:)),
      to: nil, from: nil, for: nil)
    if let responder = captured {
      captured = nil
      return responder
    }
    for window in allWindows() {
      if let view = search(window) { return view }
    }
    return nil
  }

  private static func allWindows() -> [UIWindow] {
    var windows: [UIWindow] = []
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      windows.append(contentsOf: windowScene.windows.filter { $0.isKeyWindow })
      windows.append(contentsOf: windowScene.windows.filter { !$0.isKeyWindow })
    }
    return windows
  }

  private static func search(_ view: UIView) -> UIView? {
    if view.isFirstResponder { return view }
    for subview in view.subviews {
      if let found = search(subview) { return found }
    }
    return nil
  }
}

extension UIResponder {
  @objc fileprivate func keyboardLanguage_captureFirstResponder(_ sender: Any?) {
    FirstResponderFinder.captured = self
  }
}
