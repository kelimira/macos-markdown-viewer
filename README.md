# macOS Markdown Viewer

A SwiftUI app that opens Markdown files and renders them in a window.

## Build & run
- `swift run MarkdownViewer` then File > Open, or
- `scripts/make-app.sh` builds `build/MarkdownViewer.app` (registers `.md`/`.markdown`, so Finder "Open With", Dock drops work). `open build/MarkdownViewer.app`.

## Install
Download `MarkdownViewer-<version>.zip` from the GitHub Releases page (published automatically on every push to `main`, or by pushing a `vX.Y` tag; or build locally with `scripts/make-app.sh 1.0`), unzip, and drag `MarkdownViewer.app` to `/Applications`. The app is ad-hoc signed, not notarized: first launch needs right-click > Open (or `xattr -dr com.apple.quarantine MarkdownViewer.app`).
Then right-click any `.md` file > Open With > MarkdownViewer (Get Info > Open with > Change All to make it the default).

## Tests
`swift test` — uses Swift Testing, which needs the full Xcode toolchain (Command Line Tools alone fail with "TestingMacros not found").

## Security / limits
JavaScript is disabled, a CSP only allows local images, links open in the default browser, URLs are allow-listed (http/https/mailto/relative).
Not supported: tables, nested lists, reference links.
