import Foundation

/// Per-document renderer state (link references, footnotes, heading ids).
/// shortcut: no raw block HTML (escaped except a small tag allow-list), no nested-paren URLs, no math/emoji; upgrade to swift-markdown if needed.
final class Renderer {
    private var refs: [String: (url: String, title: String)] = [:]
    private var notes: [String: String] = [:]
    private var noteOrder: [String] = []
    private var slugs: [String: Int] = [:]

    private static func make(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
    private static let refDef = make(#"^ {0,3}\[([^\]^][^\]]*)\]:\s*<?(\S+?)>?(?:\s+["'(](.*)["')])?\s*$"#)
    private static let noteDef = make(#"^\[\^([\w-]+)\]:\s*(.*)$"#)
    private static let alert = make(#"^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$"#)
    private static let delimCell = make(#"^:?-+:?$"#)
    private static let task = make(#"^\[([ xX])\] "#)

    func document(_ markdown: String) -> String {
        var lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n").map(Self.expandTabs)
        lines = extractDefinitions(lines)
        var html = blocks(lines)
        if !noteOrder.isEmpty {
            var items = "", k = 0
            while k < noteOrder.count { // inline() may append more notes while we iterate
                let id = noteOrder[k]; k += 1
                items += "<li id=\"fn-\(id)\">\(inline(notes[id] ?? "")) <a href=\"#fnref-\(id)\">&#8617;</a></li>"
            }
            html += "\n<section class=\"footnotes\"><hr><ol>\(items)</ol></section>"
        }
        return html
    }

    private static func expandTabs(_ l: String) -> String {
        let ws = l.prefix(while: { $0 == " " || $0 == "\t" })
        return ws.contains("\t") ? ws.replacingOccurrences(of: "\t", with: "    ") + l.dropFirst(ws.count) : l
    }

    // Link reference and footnote definitions may follow their use, so collect them up front (skipping fenced code).
    private func extractDefinitions(_ lines: [String]) -> [String] {
        var out: [String] = [], fence: String?, i = 0
        while i < lines.count {
            let l = lines[i], t = l.trimmingCharacters(in: .whitespaces)
            if let f = fence { if t.hasPrefix(f) { fence = nil }; out.append(l); i += 1; continue }
            if let f = Self.fenceOpen(t) { fence = f }
            else if let m = Self.groups(Self.noteDef, l) {
                var text = m[2]; i += 1
                while i < lines.count, lines[i].hasPrefix("    ") || (lines[i].isEmpty && i + 1 < lines.count && lines[i + 1].hasPrefix("    ")) {
                    text += " " + lines[i].trimmingCharacters(in: .whitespaces); i += 1
                }
                notes[m[1]] = text; continue
            } else if let m = Self.groups(Self.refDef, l) {
                refs[m[1].lowercased()] = (MarkdownHTML.escape(m[2]), MarkdownHTML.escape(m[3])); i += 1; continue
            }
            out.append(l); i += 1
        }
        return out
    }

    private static func groups(_ re: NSRegularExpression, _ s: String) -> [String]? {
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
    }

    /// Returns the closing-fence prefix (e.g. "```") if `t` opens a fenced block.
    private static func fenceOpen(_ t: String) -> String? {
        guard let c = t.first, c == "`" || c == "~" else { return nil }
        let n = t.prefix(while: { $0 == c }).count
        return n >= 3 ? String(repeating: c, count: n) : nil
    }

    private static func blank(_ l: String) -> Bool { l.allSatisfy { $0 == " " } }
    private static func indent(_ l: String) -> Int { l.prefix(while: { $0 == " " }).count }
    private static func strip(_ l: String, _ n: Int) -> String { String(l.dropFirst(min(n, indent(l)))) }

    // MARK: blocks

    private struct Marker { let ordered: Bool; let bullet: Character?; let start: Int; let width: Int; let text: String }

    private static func marker(_ line: String) -> Marker? {
        let ind = indent(line)
        guard ind < 4 else { return nil }
        let r = line.dropFirst(ind)
        var head = 0, ordered = false, start = 0, bullet: Character?
        if let c = r.first, "-*+".contains(c) { head = 1; bullet = c }
        else {
            let d = r.prefix(while: \.isASCII).prefix(while: \.isNumber)
            guard (1...9).contains(d.count), let c = r.dropFirst(d.count).first, c == "." || c == ")" else { return nil }
            head = d.count + 1; ordered = true; start = Int(d)!
        }
        let rest = r.dropFirst(head)
        let sp = rest.prefix(while: { $0 == " " }).count
        guard sp >= 1, rest.count > sp else { return nil }
        let pad = sp > 4 ? 1 : sp
        return Marker(ordered: ordered, bullet: bullet, start: start, width: ind + head + pad, text: String(rest.dropFirst(pad)))
    }

    private func blocks(_ lines: [String], tight: Bool = false) -> String {
        var out: [String] = [], para: [String] = [], i = 0
        func flush() {
            guard !para.isEmpty else { return }
            let h = inline(para.joined(separator: "\n"))
            out.append(tight ? h : "<p>\(h)</p>"); para = []
        }
        func isTableStart(_ k: Int) -> [String?]? {
            guard k + 1 < lines.count, lines[k].contains("|"), lines[k + 1].contains("|"),
                  let al = Self.alignments(lines[k + 1]), al.count == Self.cells(lines[k]).count else { return nil }
            return al
        }

        while i < lines.count {
            let line = lines[i], t = line.trimmingCharacters(in: .whitespaces), ind = Self.indent(line)

            if t.isEmpty { flush(); i += 1; continue }

            if ind < 4, let fence = Self.fenceOpen(t) {
                flush()
                let info = t.dropFirst(fence.count).trimmingCharacters(in: .whitespaces)
                let lang = String(info.prefix(while: { $0 != " " }).filter { $0.isLetter || $0.isNumber || "-_+#.".contains($0) })
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) { code.append(Self.strip(lines[i], ind)); i += 1 }
                i += 1
                let cls = lang.isEmpty ? "" : " class=\"language-\(lang)\""
                out.append("<pre><code\(cls)>\(MarkdownHTML.escape(code.joined(separator: "\n")))</code></pre>")
            } else if ind >= 4 && para.isEmpty {
                var code: [String] = []
                while i < lines.count, Self.blank(lines[i]) || Self.indent(lines[i]) >= 4 { code.append(Self.strip(lines[i], 4)); i += 1 }
                while code.last.map(Self.blank) == true { code.removeLast() }
                out.append("<pre><code>\(MarkdownHTML.escape(code.joined(separator: "\n")))</code></pre>")
            } else if t.hasPrefix("<!--") {
                flush()
                while i < lines.count, !lines[i].contains("-->") { i += 1 }
                i += 1
            } else if t == "<details>" || t == "</details>" || t == "<details open>" {
                flush(); out.append(t); i += 1
            } else if t.hasPrefix("<summary>"), t.hasSuffix("</summary>") {
                flush(); out.append("<summary>\(inline(String(t.dropFirst(9).dropLast(10))))</summary>"); i += 1
            } else if let al = isTableStart(i) {
                flush()
                let head = Self.cells(line)
                func row(_ cs: [String], _ tag: String) -> String {
                    "<tr>" + (0..<head.count).map { c in
                        let a = al[c].map { " style=\"text-align:\($0)\"" } ?? ""
                        return "<\(tag)\(a)>\(inline(c < cs.count ? cs[c] : ""))</\(tag)>"
                    }.joined() + "</tr>"
                }
                var body: [String] = []
                i += 2
                while i < lines.count, !Self.blank(lines[i]), !["#", ">", "`", "~"].contains(lines[i].trimmingCharacters(in: .whitespaces).first!) {
                    body.append(row(Self.cells(lines[i]), "td")); i += 1
                }
                out.append("<table><thead>\(row(head, "th"))</thead>" + (body.isEmpty ? "" : "<tbody>\(body.joined())</tbody>") + "</table>")
            } else if ind < 4, let h = atx(t) {
                flush(); out.append(h); i += 1
            } else if ind < 4, !para.isEmpty, let c = t.first, c == "=" || c == "-", t.allSatisfy({ $0 == c }) {
                let text = inline(para.joined(separator: "\n")); para = []
                out.append("<h\(c == "=" ? 1 : 2) id=\"\(slug(text))\">\(text)</h\(c == "=" ? 1 : 2)>"); i += 1
            } else if case let r = t.filter({ $0 != " " }), r.count >= 3, Set(r).count == 1, "-*_".contains(r.first!) {
                flush(); out.append("<hr>"); i += 1
            } else if t.hasPrefix(">") {
                flush()
                var q: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    var s = lines[i].trimmingCharacters(in: .whitespaces).dropFirst()
                    if s.first == " " { s = s.dropFirst() }
                    q.append(String(s)); i += 1
                }
                if let m = Self.groups(Self.alert, q[0]) {
                    let kind = m[1].lowercased()
                    out.append("<div class=\"alert alert-\(kind)\"><p class=\"alert-title\">\(kind.capitalized)</p>\(blocks(Array(q.dropFirst())))</div>")
                } else { out.append("<blockquote>\(blocks(q))</blockquote>") }
            } else if let first = Self.marker(line) {
                flush()
                var items: [String] = [], loose = false
                while i < lines.count, let m = Self.marker(lines[i]), m.ordered == first.ordered, m.bullet == first.bullet {
                    var item = [m.text]
                    i += 1
                    while i < lines.count {
                        let l = lines[i]
                        if Self.blank(l) {
                            var j = i
                            while j < lines.count, Self.blank(lines[j]) { j += 1 }
                            guard j < lines.count, Self.indent(lines[j]) >= m.width else { break }
                            item += Array(repeating: "", count: j - i); i = j; loose = true
                        } else if Self.indent(l) >= m.width { item.append(Self.strip(l, m.width)); i += 1 }
                        else if !Self.blank(item.last!), Self.marker(l) == nil, Self.fenceOpen(l.trimmingCharacters(in: .whitespaces)) == nil,
                                !l.trimmingCharacters(in: .whitespaces).hasPrefix(">"), !l.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                            item.append(l.trimmingCharacters(in: .whitespaces)); i += 1 // lazy continuation
                        } else { break }
                    }
                    items.append(item.joined(separator: "\n"))
                    var j = i
                    while j < lines.count, Self.blank(lines[j]) { j += 1 }
                    if j > i {
                        guard j < lines.count, let n = Self.marker(lines[j]), n.ordered == first.ordered, n.bullet == first.bullet else { break }
                        loose = true; i = j
                    }
                }
                let tag = first.ordered ? "ol" : "ul", start = first.ordered && first.start != 1 ? " start=\"\(first.start)\"" : ""
                let lis = items.map { raw -> String in
                    var cls = "", cb = ""
                    var text = raw
                    if let m = Self.groups(Self.task, raw) {
                        cls = " class=\"task\""; text = String(raw.dropFirst(4))
                        cb = "<input type=\"checkbox\" disabled\(m[1] == " " ? "" : " checked")> "
                    }
                    var h = blocks(text.components(separatedBy: "\n"), tight: !loose)
                    if h.hasPrefix("<p>") { h = "<p>" + cb + h.dropFirst(3) } else { h = cb + h }
                    return "<li\(cls)>\(h)</li>"
                }
                out.append("<\(tag)\(start)>\(lis.joined())</\(tag)>")
            } else {
                para.append(String(line.drop(while: { $0 == " " }))); i += 1
            }
        }
        flush()
        return out.joined(separator: "\n")
    }

    private func atx(_ t: String) -> String? {
        let hashes = t.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), t.count == hashes || t.dropFirst(hashes).first == " " else { return nil }
        var text = t.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
        if let r = text.range(of: #"(^|\s)#+$"#, options: .regularExpression) { text = String(text[..<r.lowerBound]).trimmingCharacters(in: .whitespaces) }
        let h = inline(text)
        return "<h\(hashes) id=\"\(slug(h))\">\(h)</h\(hashes)>"
    }

    /// GitHub-style anchor, de-duplicated with -1, -2, ...
    private func slug(_ html: String) -> String {
        let plain = html.replacingOccurrences(of: "<[^>]*>|&[#\\w]+;", with: "", options: .regularExpression).lowercased()
        var s = String(plain.filter { $0.isLetter || $0.isNumber || " -_".contains($0) }).replacingOccurrences(of: " ", with: "-")
        if s.isEmpty { s = "section" }
        let n = slugs[s, default: 0]; slugs[s] = n + 1
        return n == 0 ? s : "\(s)-\(n)"
    }

    // MARK: tables

    private static func cells(_ row: String) -> [String] {
        var s = row.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") && !s.hasSuffix("\\|") { s.removeLast() }
        var out: [String] = [], cur = "", esc = false
        for ch in s {
            if esc { cur += ch == "|" ? "|" : "\\\(ch)"; esc = false }
            else if ch == "\\" { esc = true }
            else if ch == "|" { out.append(cur.trimmingCharacters(in: .whitespaces)); cur = "" }
            else { cur.append(ch) }
        }
        if esc { cur += "\\" }
        return out + [cur.trimmingCharacters(in: .whitespaces)]
    }

    /// Per-column alignment if `row` is a table delimiter row (---, :--, --:, :-:).
    private static func alignments(_ row: String) -> [String?]? {
        let cs = cells(row)
        guard cs.allSatisfy({ groups(delimCell, $0) != nil }) else { return nil }
        return cs.map { $0.hasPrefix(":") ? ($0.hasSuffix(":") ? "center" : "left") : ($0.hasSuffix(":") ? "right" : nil) }
    }

    // MARK: inline

    private enum re {
        static func make(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
        static let code = make(#"(`+)(.+?)\1(?!`)"#)
        static let escaped = make(#"\\(&amp;|&lt;|&gt;|&quot;|[!-/:-@\[-`{-~])"#)
        static let tag = make(#"&lt;(/?)(br|kbd|sub|sup|mark|ins|b|i|u)\s*/?&gt;"#)
        static let autolink = make(#"&lt;((?:https?://|mailto:)[^\s]*?)&gt;"#)
        static let email = make(#"&lt;([\w.+-]+@[\w-]+\.[\w.-]+)&gt;"#)
        static let note = make(#"\[\^([\w-]+)\]"#)
        static let imageRef = make(#"!\[([^\]]*)\]\[([^\]]*)\]"#)
        static let image = make(#"!\[([^\]]*)\]\(\s*([^)\s]+)(?:\s+&quot;(.*?)&quot;)?\s*\)"#)
        static let link = make(#"\[([^\]]+)\]\(\s*([^)\s]+)(?:\s+&quot;(.*?)&quot;)?\s*\)"#)
        static let linkRef = make(#"\[([^\]]+)\]\[([^\]]*)\]"#)
        static let shortRef = make(#"\[([^\]]+)\](?![\[(:])"#)
        static let bare = make(#"(?<![\w\u{0}\[])https?://[^\s<]*[^\s<.,:;!?)\]'*_~]"#)
        static let strongEm = make(#"\*\*\*(.+?)\*\*\*"#)
        static let strong = make(#"\*\*(.+?)\*\*|(?<!\w)__(.+?)__(?!\w)"#)
        // Two alternatives per rule (* or _); the unmatched group is empty.
        static let em = make(#"(?<![\w*])\*(?!\s)(.+?)\*(?!\w)|(?<![\w_])_(?!\s)(.+?)_(?![\w_])"#)
        static let del = make(#"~~(.+?)~~"#)
        static let hardBreak = make(#"(?: {2,}|\\)\n"#)
        static let slot = make("\u{0}(\\d+)\u{0}")
    }

    func inline(_ raw: String) -> String {
        let r = MarkdownHTML.replace
        // Drop NULs from input so user text can't collide with our placeholders.
        var s = MarkdownHTML.escape(raw.replacingOccurrences(of: "\u{0}", with: ""))
        // Code spans, images, escapes and link openers are stashed so emphasis rules can't touch URLs/attributes.
        var stash: [String] = []
        func hold(_ html: String) -> String { stash.append(html); return "\u{0}\(stash.count - 1)\u{0}" }
        func img(_ alt: String, _ url: String, _ title: String) -> String {
            "<img alt=\"\(alt)\" src=\"\(MarkdownHTML.safeURL(url))\"\(title.isEmpty ? "" : " title=\"\(title)\"")>"
        }
        func open(_ url: String, _ title: String) -> String {
            "<a href=\"\(MarkdownHTML.safeURL(url))\"\(title.isEmpty ? "" : " title=\"\(title)\"")>"
        }
        func ref(_ label: String, _ text: String) -> (url: String, title: String)? { refs[(label.isEmpty ? text : label).lowercased()] }

        s = r(s, re.code) { hold("<code>\($0[2].trimmingCharacters(in: .whitespaces))</code>") }
        s = r(s, re.escaped) { hold($0[1]) }
        s = r(s, re.tag) { hold($0[2] == "br" ? ($0[1].isEmpty ? "<br>" : "") : "<\($0[1])\($0[2])>") }
        s = r(s, re.autolink) { hold(open($0[1], "") + $0[1] + "</a>") }
        s = r(s, re.email) { hold(open("mailto:" + $0[1], "") + $0[1] + "</a>") }
        s = r(s, re.note) { m in
            guard notes[m[1]] != nil else { return m[0] }
            if !noteOrder.contains(m[1]) { noteOrder.append(m[1]) }
            return hold("<sup id=\"fnref-\(m[1])\"><a href=\"#fn-\(m[1])\">\(noteOrder.firstIndex(of: m[1])! + 1)</a></sup>")
        }
        s = r(s, re.image) { hold(img($0[1], $0[2], $0[3])) }
        s = r(s, re.imageRef) { m in ref(m[2], m[1]).map { hold(img(m[1], $0.url, $0.title)) } ?? m[0] }
        s = r(s, re.link) { hold(open($0[2], $0[3])) + $0[1] + "</a>" }
        s = r(s, re.linkRef) { m in ref(m[2], m[1]).map { hold(open($0.url, $0.title)) + m[1] + "</a>" } ?? m[0] }
        s = r(s, re.shortRef) { m in ref("", m[1]).map { hold(open($0.url, $0.title)) + m[1] + "</a>" } ?? m[0] }
        s = r(s, re.bare) { hold(open($0[0], "") + $0[0] + "</a>") }
        s = r(s, re.strongEm) { "<strong><em>\($0[1])</em></strong>" }
        s = r(s, re.strong) { "<strong>\($0[1] + $0[2])</strong>" }
        s = r(s, re.em) { "<em>\($0[1] + $0[2])</em>" }
        s = r(s, re.del) { "<del>\($0[1])</del>" }
        s = r(s, re.hardBreak) { _ in hold("<br>") + "\n" }
        s = s.replacingOccurrences(of: "\n", with: " ")
        return r(s, re.slot) { stash[Int($0[1])!] }
    }
}
