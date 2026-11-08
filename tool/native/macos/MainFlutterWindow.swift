import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  private var windowChannel: FlutterMethodChannel?
  private var normalStyleMask: NSWindow.StyleMask?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // A see-through window, so "Transparent background" shows the real desktop.
    self.isOpaque = false
    self.backgroundColor = .clear
    flutterViewController.backgroundColor = .clear

    // Channel used by lib/desktop.dart to switch "clear mode" on and off.
    let channel = FlutterMethodChannel(
      name: "screen_widget/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return result(nil) }
      switch call.method {
      case "setClearMode":
        self.setClearMode((call.arguments as? Bool) ?? false)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    windowChannel = channel

    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }

  /// Clear mode = transparent background: a borderless window, so macOS draws
  /// no frame edge, rounded corners or shadow — only what Flutter paints (the
  /// tree and its animation). Turning it off restores the normal window.
  func setClearMode(_ on: Bool) {
    if on {
      if normalStyleMask == nil || styleMask.contains(.titled) { normalStyleMask = styleMask }
      styleMask = [.borderless, .resizable, .miniaturizable]
      hasShadow = false
    } else {
      styleMask = normalStyleMask ?? [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
      titleVisibility = .hidden
      titlebarAppearsTransparent = true
      hasShadow = true
    }
    isOpaque = false
    backgroundColor = .clear
    invalidateShadow()
  }

  // A borderless window (transparent mode) has no close button, so AppKit's
  // performClose just beeps. Run the normal close check (window_manager's
  // windowShouldClose, which tells Flutter) and close if it's allowed.
  override func performClose(_ sender: Any?) {
    if styleMask.contains(.closable) {
      super.performClose(sender)
      return
    }
    if delegate?.windowShouldClose?(self) ?? true {
      close()
    }
  }

  // Borderless windows can't take keyboard focus by default; keep shortcuts working.
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  // window_manager: keep the window hidden until Flutter is ready to show it.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
