import Foundation

/// Minimal Markdown -> HTML converter.
/// GFM-style: tables, nested/loose/task lists, reference links, footnotes, alerts, autolinks. Not full CommonMark (see Renderer).
public enum MarkdownHTML {
    /// Only web/mail links may leave the app; file: and other schemes could launch local apps.
    public static func isExternallyOpenable(_ u: URL) -> Bool {
        ["http", "https", "mailto"].contains(u.scheme?.lowercased() ?? "")
    }

    public static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    public static func render(_ markdown: String) -> String { Renderer().document(markdown) }
    static func inline(_ raw: String) -> String { Renderer().inline(raw) }

    // Allow-list: http, https, mailto, or a scheme-less relative URL. Input is already HTML-escaped.
    static func safeURL(_ u: String) -> String {
        // Browsers ignore C0 controls/whitespace inside a scheme, so strip them before checking.
        let c = String(u.unicodeScalars.filter { $0.value > 0x20 && $0.value != 0x7f })
        guard let colon = c.firstIndex(of: ":"),
              !c[..<colon].contains(where: { "/?#".contains($0) }) else { return c }
        return ["http", "https", "mailto"].contains(c[..<colon].lowercased()) ? c : "#"
    }

    static func replace(_ s: String, _ re: NSRegularExpression, _ f: ([String]) -> String) -> String {
        let ns = s as NSString
        var result = "", last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            result += f((0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) })
            last = m.range.location + m.range.length
        }
        return result + ns.substring(from: last)
    }

    public static func page(_ markdown: String) -> String {
        """
        <!DOCTYPE html><html><head><meta charset="utf-8"><meta name="color-scheme" content="light dark">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src file: https:; style-src 'unsafe-inline'">
        <style>body{font:15px/1.6 -apple-system,sans-serif;max-width:760px;margin:2em auto;padding:0 1em}
        pre{background:rgba(127,127,127,.15);padding:1em;overflow:auto;border-radius:6px}
        code{font-family:ui-monospace,Menlo,monospace;background:rgba(127,127,127,.15);padding:.1em .3em;border-radius:3px}
        pre code{background:none;padding:0}blockquote{border-left:4px solid #888;margin:0;padding-left:1em;color:gray}
        img{max-width:100%}table{border-collapse:collapse;display:block;overflow:auto;margin:1em 0}
        th,td{border:1px solid rgba(127,127,127,.4);padding:.4em .8em}th{background:rgba(127,127,127,.15)}tr:nth-child(even) td{background:rgba(127,127,127,.06)}
        hr{border:0;border-top:1px solid rgba(127,127,127,.4)}li.task{list-style:none;margin-left:-1.4em}li.task input{margin-right:.5em}
        .alert{border-left:4px solid #58a6ff;padding:.1em 1em;margin:1em 0;background:rgba(88,166,255,.1)}.alert-title{font-weight:600}
        .alert-warning,.alert-caution{border-color:#d29922;background:rgba(210,153,34,.1)}.footnotes{font-size:.9em}summary{cursor:pointer}
        kbd{font:.85em ui-monospace,Menlo,monospace;border:1px solid rgba(127,127,127,.5);border-radius:3px;padding:.1em .4em}</style></head><body>\(render(markdown))</body></html>
        """
    }
}
