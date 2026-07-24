import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers
import window_manager

class DropOverlayView: NSView {
    var methodChannel: FlutterMethodChannel?
    private var isActive = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    func setActive(_ active: Bool) {
        isActive = active
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isActive else { return [] }
        methodChannel?.invokeMethod("dragEntered", arguments: nil)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard isActive else { return }
        methodChannel?.invokeMethod("dragExited", arguments: nil)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard isActive else { return false }
        let pasteboard = sender.draggingPasteboard
        guard let items = pasteboard.pasteboardItems else { return false }
        var paths: [String] = []
        for item in items {
            if let urlStr = item.string(forType: .fileURL),
               let url = URL(string: urlStr) {
                paths.append(url.path)
            }
        }
        guard !paths.isEmpty else { return false }
        methodChannel?.invokeMethod("dragDone", arguments: paths)
        return true
    }
}

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let width = min(screenFrame.width * 0.8, 1600)
            let height = min(screenFrame.height * 0.8, 1000)
            let x = (screenFrame.width - width) / 2 + screenFrame.origin.x
            let y = (screenFrame.height - height) / 2 + screenFrame.origin.y
            self.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        } else {
            self.setFrame(NSRect(x: 0, y: 0, width: 1400, height: 900), display: true)
        }

        self.minSize = NSSize(width: 900, height: 600)

        RegisterGeneratedPlugins(registry: flutterViewController)

        let dropChannel = FlutterMethodChannel(
            name: "mac_drop",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )

        let flutterView = flutterViewController.view
        let dropView = DropOverlayView(frame: flutterView.bounds)
        dropView.methodChannel = dropChannel
        dropView.translatesAutoresizingMaskIntoConstraints = false
        flutterView.addSubview(dropView, positioned: .above, relativeTo: nil)

        NSLayoutConstraint.activate([
            dropView.leadingAnchor.constraint(equalTo: flutterView.leadingAnchor),
            dropView.trailingAnchor.constraint(equalTo: flutterView.trailingAnchor),
            dropView.topAnchor.constraint(equalTo: flutterView.topAnchor),
            dropView.bottomAnchor.constraint(equalTo: flutterView.bottomAnchor),
        ])

        dropChannel.setMethodCallHandler { [weak dropView] call, result in
            switch call.method {
            case "setActive":
                if let active = call.arguments as? Bool {
                    dropView?.setActive(active)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARG", message: nil, details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        super.awakeFromNib()
    }

    // Window Manager: hide window at launch to prevent flash
    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        super.order(place, relativeTo: otherWin)
        hiddenWindowAtLaunch()
    }
}
