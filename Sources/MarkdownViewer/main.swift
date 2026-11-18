import SwiftUI
import WebKit
import MarkdownCore
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "markdown") ?? .plainText, .plainText]
    }
    var text: String

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let s = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        text = s
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { throw CocoaError(.fileWriteNoPermission) }
}

struct WebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded: String?
        let id = UUID().uuidString
        // Open clicked links in the default browser instead of replacing the document.
        func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if a.navigationType == .linkActivated {
                if let u = a.request.url, MarkdownHTML.isExternallyOpenable(u) { NSWorkspace.shared.open(u) }
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = false
        let v = WKWebView(frame: .zero, configuration: cfg)
        v.navigationDelegate = context.coordinator
        return v
    }
    func updateNSView(_ v: WKWebView, context: Context) {
        guard context.coordinator.loaded != html else { return } // keep scroll position
        context.coordinator.loaded = html
        // loadHTMLString grants no file access, so relative images would break; load from a temp file instead.
        guard let base = baseURL else { v.loadHTMLString(html, baseURL: nil); return }
        let page = html.replacingOccurrences(of: "<head>", with: "<head><base href=\"\(MarkdownHTML.escape(base.absoluteString))\">")
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mdviewer-\(context.coordinator.id).html")
        do {
            try page.write(to: tmp, atomically: true, encoding: .utf8)
            // Read access to "/" so the temp page can load images beside the document; JS is off and CSP limits loads to img.
            v.loadFileURL(tmp, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        } catch { v.loadHTMLString(html, baseURL: base) }
    }
}

struct MarkdownApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            WebView(html: MarkdownHTML.page(file.document.text), baseURL: file.fileURL)
                .frame(minWidth: 480, minHeight: 360)
        }
    }
}

NSApplication.shared.setActivationPolicy(.regular)
MarkdownApp.main()
