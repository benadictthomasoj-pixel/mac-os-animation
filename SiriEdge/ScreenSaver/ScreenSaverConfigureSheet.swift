import AppKit
import SwiftUI

/// Window controller presenting the SiriEdge configuration sheet in System Settings Screen Saver pane.
public final class ScreenSaverConfigureSheetController: NSWindowController {
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SiriEdge Options"
        window.minSize = NSSize(width: 420, height: 600)
        
        let hostingView = NSHostingView(rootView: ScreenSaverSettingsSheetView(onDone: { [weak window] in
            guard let win = window else { return }
            if let parent = win.sheetParent {
                parent.endSheet(win)
            } else {
                win.close()
            }
        }))
        
        window.contentView = hostingView
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// SwiftUI settings sheet view tailored for the Screen Saver configuration modal.
public struct ScreenSaverSettingsSheetView: View {
    @ObservedObject var settings = EdgeSettings.shared
    var onDone: () -> Void
    
    public init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            SettingsView()
            
            Divider()
            
            HStack {
                Spacer()
                Button("Done") {
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 420, idealWidth: 460, maxWidth: 480)
        .frame(minHeight: 650, idealHeight: 740)
    }
}
