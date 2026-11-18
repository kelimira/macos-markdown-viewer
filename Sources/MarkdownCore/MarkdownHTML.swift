import Foundation

/// Minimal Markdown -> HTML converter.
/// shortcut: no tables, nested lists, loose lists, or reference links; swap in swift-markdown if needed.
public enum MarkdownHTML {
    public static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    public static func render(_ markdown: String) -> String {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var out: [String] = []
        var para: [String] = []
        var i = 0

        func flush() {
            if !para.isEmpty { out.append("<p>\(inline(para.joined(separator: " ")))</p>"); para = [] }
        }

        while i < lines.count {
            let line = lines[i]
            let t = line.trimmingCharacters(in: .whitespaces)

            if t.hasPrefix("```") {
                flush()
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i]); i += 1
                }
                out.append("<pre><code>\(escape(code.joined(separator: "\n")))</code></pre>")
            } else if t.isEmpty {
                flush()
            } else if let h = heading(t) {
                flush(); out.append(h)
            } else if case let r = t.filter({ $0 != " " }), r.count >= 3, Set(r).count == 1, "-*_".contains(r.first!) {
                flush(); out.append("<hr>")
            } else if t.hasPrefix(">") {
                flush()
                var q: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    q.append(String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                i -= 1
                out.append("<blockquote>\(render(q.joined(separator: "\n")))</blockquote>")
            } else if let (ordered, _) = listItem(t) {
                flush()
                var items: [String] = []
                while i < lines.count, let (o, text) = listItem(lines[i].trimmingCharacters(in: .whitespaces)), o == ordered {
                    items.append("<li>\(inline(text))</li>"); i += 1
                }
                i -= 1
                let tag = ordered ? "ol" : "ul"
                out.append("<\(tag)>\(items.joined())</\(tag)>")
            } else {
                para.append(t)
            }
            i += 1
        }
        flush()
        return out.joined(separator: "\n")
    }

    static func heading(_ t: String) -> String? {
        let hashes = t.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), t.dropFirst(hashes).first == " " else { return nil }
        return "<h\(hashes)>\(inline(String(t.dropFirst(hashes + 1)).trimmingCharacters(in: .whitespaces)))</h\(hashes)>"
    }

    static func listItem(_ t: String) -> (Bool, String)? {
        if t.count > 2, "-*+".contains(t.first!), t.dropFirst().first == " " { return (false, String(t.dropFirst(2))) }
        let digits = t.prefix(while: \.isNumber)
        if !digits.isEmpty, t.dropFirst(digits.count).hasPrefix(". ") { return (true, String(t.dropFirst(digits.count + 2))) }
        return nil
    }

    static func inline(_ raw: String) -> String {
        // Drop NULs from input so user text can't collide with our placeholders.
        var s = escape(raw.replacingOccurrences(of: "\u{0}", with: ""))
        // Code spans, images and link openers are stashed so emphasis rules can't touch URLs/attributes.
        var stash: [String] = []
        func hold(_ html: String) -> String { stash.append(html); return "\u{0}\(stash.count - 1)\u{0}" }
        s = replace(s, re.code) { hold("<code>\($0[1])</code>") }
        s = replace(s, re.image) { hold("<img alt=\"\($0[1])\" src=\"\(safeURL($0[2]))\">") }
        s = replace(s, re.link) { hold("<a href=\"\(safeURL($0[2]))\">") + $0[1] + "</a>" }
        s = replace(s, re.strong) { "<strong>\($0[1] + $0[2])</strong>" }
        s = replace(s, re.em) { "<em>\($0[1] + $0[2])</em>" }
        s = replace(s, re.del) { "<del>\($0[1])</del>" }
        return replace(s, re.slot) { stash[Int($0[1])!] }
    }

    private enum re {
        static func make(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
        static let code = make(#"`([^`]+)`"#)
        static let image = make(#"!\[([^\]]*)\]\(([^)\s]+)\)"#)
        static let link = make(#"\[([^\]]+)\]\(([^)\s]+)\)"#)
        // Two alternatives per rule (* or _); the unmatched group is empty.
        static let strong = make(#"\*\*(.+?)\*\*|(?<!\w)__(.+?)__(?!\w)"#)
        static let em = make(#"(?<![\w*])\*(?!\s)(.+?)\*(?!\w)|(?<![\w_])_(?!\s)(.+?)_(?![\w_])"#)
        static let del = make(#"~~(.+?)~~"#)
        static let slot = make("\u{0}(\\d+)\u{0}")
    }

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
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src file:; style-src 'unsafe-inline'">
        <style>body{font:15px/1.6 -apple-system,sans-serif;max-width:760px;margin:2em auto;padding:0 1em}
        pre{background:rgba(127,127,127,.15);padding:1em;overflow:auto;border-radius:6px}
        code{font-family:ui-monospace,Menlo,monospace;background:rgba(127,127,127,.15);padding:.1em .3em;border-radius:3px}
        pre code{background:none;padding:0}blockquote{border-left:4px solid #888;margin:0;padding-left:1em;color:gray}
        img{max-width:100%}</style></head><body>\(render(markdown))</body></html>
        """
    }
}
