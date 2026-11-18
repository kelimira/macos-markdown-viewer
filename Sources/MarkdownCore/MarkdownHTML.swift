import Foundation

/// Minimal Markdown -> HTML converter.
/// shortcut: no tables, nested lists, or reference links; swap in swift-markdown if needed.
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
            } else if t.count >= 3, Set(t).count == 1, "-*_".contains(t.first!) {
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
        var s = escape(raw)
        // Code spans first, stashed so other rules don't touch them.
        var spans: [String] = []
        s = replace(s, #"`([^`]+)`"#) { m in spans.append("<code>\(m[1])</code>"); return "\u{0}\(spans.count - 1)\u{0}" }
        s = replace(s, #"!\[([^\]]*)\]\(([^)\s]+)\)"#) { m in "<img alt=\"\(m[1])\" src=\"\(safeURL(m[2]))\">" }
        s = replace(s, #"\[([^\]]+)\]\(([^)\s]+)\)"#) { m in "<a href=\"\(safeURL(m[2]))\">\(m[1])</a>" }
        s = replace(s, #"\*\*(.+?)\*\*"#) { "<strong>\($0[1])</strong>" }
        s = replace(s, #"(?<![\w*])\*(?!\s)(.+?)\*(?!\w)"#) { "<em>\($0[1])</em>" }
        s = replace(s, #"~~(.+?)~~"#) { "<del>\($0[1])</del>" }
        for (n, span) in spans.enumerated() { s = s.replacingOccurrences(of: "\u{0}\(n)\u{0}", with: span) }
        return s
    }

    // Block javascript:/data: URLs (input is already HTML-escaped).
    static func safeURL(_ u: String) -> String {
        let l = u.lowercased()
        return (l.hasPrefix("javascript:") || l.hasPrefix("data:") || l.hasPrefix("vbscript:")) ? "#" : u
    }

    static func replace(_ s: String, _ pattern: String, _ f: ([String]) -> String) -> String {
        let re = try! NSRegularExpression(pattern: pattern)
        let ns = s as NSString
        var result = "", last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            result += f((0..<m.numberOfRanges).map { ns.substring(with: m.range(at: $0)) })
            last = m.range.location + m.range.length
        }
        return result + ns.substring(from: last)
    }

    public static func page(_ markdown: String) -> String {
        """
        <!DOCTYPE html><html><head><meta charset="utf-8"><meta name="color-scheme" content="light dark">
        <style>body{font:15px/1.6 -apple-system,sans-serif;max-width:760px;margin:2em auto;padding:0 1em}
        pre{background:rgba(127,127,127,.15);padding:1em;overflow:auto;border-radius:6px}
        code{font-family:ui-monospace,Menlo,monospace;background:rgba(127,127,127,.15);padding:.1em .3em;border-radius:3px}
        pre code{background:none;padding:0}blockquote{border-left:4px solid #888;margin:0;padding-left:1em;color:gray}
        img{max-width:100%}</style></head><body>\(render(markdown))</body></html>
        """
    }
}
