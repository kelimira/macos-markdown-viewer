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
    func makeNSView(context: Context) -> WKWebView { WKWebView() }
    func updateNSView(_ v: WKWebView, context: Context) { v.loadHTMLString(html, baseURL: nil) }
}

struct MarkdownApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            WebView(html: MarkdownHTML.page(file.document.text)).frame(minWidth: 480, minHeight: 360)
        }
    }
}

NSApplication.shared.setActivationPolicy(.regular)
MarkdownApp.main()
