# macOS Markdown Viewer

A SwiftUI app that opens Markdown files and renders them in a window.

## Build & run
- `swift run MarkdownViewer` then File > Open, or
- `scripts/make-app.sh` builds `build/MarkdownViewer.app` (registers `.md`/`.markdown`, so Finder "Open With", Dock drops work). `open build/MarkdownViewer.app`.

## Tests
`swift test` — uses Swift Testing, which needs the full Xcode toolchain (Command Line Tools alone fail with "TestingMacros not found").

## Security / limits
JavaScript is disabled, a CSP only allows local images, links open in the default browser, URLs are allow-listed (http/https/mailto/relative).
Not supported: tables, nested lists, reference links.
