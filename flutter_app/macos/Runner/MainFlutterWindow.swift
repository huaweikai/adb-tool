import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

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

    super.awakeFromNib()
  }
}
