import Foundation
import Testing
@testable import MarkdownCore

struct MarkdownHTMLTests {
    @Test func externalLinkPolicy() {
        for ok in ["http://a.com", "HTTPS://a.com", "mailto:a@b.c"] { #expect(MarkdownHTML.isExternallyOpenable(URL(string: ok)!)) }
        for bad in ["file:///x/run.command", "x-apple.systempreferences:", "javascript:1"] { #expect(!MarkdownHTML.isExternallyOpenable(URL(string: bad)!)) }
    }

    @Test func headingAndParagraph() {
        #expect(MarkdownHTML.render("# Hi\n\nsome *text*\nmore") == "<h1 id=\"hi\">Hi</h1>\n<p>some <em>text</em> more</p>")
    }
    @Test func codeFenceEscapes() {
        #expect(MarkdownHTML.render("```\n<b>&\n```") == "<pre><code>&lt;b&gt;&amp;</code></pre>")
    }
    @Test func lists() {
        #expect(MarkdownHTML.render("- a\n- b") == "<ul><li>a</li><li>b</li></ul>")
        #expect(MarkdownHTML.render("1. a\n2. b") == "<ol><li>a</li><li>b</li></ol>")
    }
    @Test func inline() {
        #expect(MarkdownHTML.inline("**b** `*x*` [l](http://e.com)")
                == "<strong>b</strong> <code>*x*</code> <a href=\"http://e.com\">l</a>")
    }
    @Test func blockquoteAndRule() {
        #expect(MarkdownHTML.render("> q\n\n---") == "<blockquote><p>q</p></blockquote>\n<hr>")
    }
    @Test func scriptAndJavascriptUrlNeutralised() {
        #expect(!MarkdownHTML.render("<script>x</script>").contains("<script>"))
        #expect(MarkdownHTML.render("[a](javascript:alert(1))").contains("href=\"#\""))
    }
    @Test func emptyInput() { #expect(MarkdownHTML.render("").isEmpty) }

    @Test func safeURLAllowList() {
        #expect(MarkdownHTML.safeURL("\u{1}javascript:alert(1)") == "#")
        #expect(MarkdownHTML.safeURL("JaVaScRiPt:x") == "#")
        #expect(MarkdownHTML.safeURL("data:text/html,x") == "#")
        #expect(MarkdownHTML.safeURL("file:///etc/passwd") == "#")
        #expect(MarkdownHTML.safeURL("HTTPS://e.com") == "HTTPS://e.com")
        #expect(MarkdownHTML.safeURL("mailto:a@b.c") == "mailto:a@b.c")
        #expect(MarkdownHTML.safeURL("img/a:b.png") == "img/a:b.png")
        #expect(MarkdownHTML.safeURL("#frag") == "#frag")
    }
    @Test func imageRendering() {
        #expect(MarkdownHTML.inline("![alt](pic.png)") == "<img alt=\"alt\" src=\"pic.png\">")
    }
    @Test func emphasisDoesNotMangleUrls() {
        #expect(MarkdownHTML.inline("[a](http://x/**y**)") == "<a href=\"http://x/**y**\">a</a>")
    }
    @Test func underscoreEmphasis() {
        #expect(MarkdownHTML.inline("_e_ __s__ snake_case_name") == "<em>e</em> <strong>s</strong> snake_case_name")
    }
    @Test func placeholderCollisionIgnored() {
        #expect(MarkdownHTML.inline("`a` \u{0}0\u{0}") == "<code>a</code> 0")
    }
    @Test func unclosedFence() {
        #expect(MarkdownHTML.render("```\ncode") == "<pre><code>code</code></pre>")
    }
    @Test func crlfAndMixedLists() {
        #expect(MarkdownHTML.render("- a\r\n1. b") == "<ul><li>a</li></ul>\n<ol><li>b</li></ol>")
    }
    @Test func multiParagraphBlockquote() {
        #expect(MarkdownHTML.render("> a\n>\n> b") == "<blockquote><p>a</p>\n<p>b</p></blockquote>")
    }
    @Test func spacedRule() { #expect(MarkdownHTML.render("* * *") == "<hr>") }
    @Test func pageWrapsBody() {
        let p = MarkdownHTML.page("# T")
        #expect(p.contains("<h1 id=\"t\">T</h1>") && p.contains("Content-Security-Policy"))
    }

    @Test func tableWithAlignment() {
        let h = MarkdownHTML.render("| A | B |\n|:--|--:|\n| 1 | **2** |\n| x \\| y |")
        #expect(h == "<table><thead><tr><th style=\"text-align:left\">A</th><th style=\"text-align:right\">B</th></tr></thead>"
            + "<tbody><tr><td style=\"text-align:left\">1</td><td style=\"text-align:right\"><strong>2</strong></td></tr>"
            + "<tr><td style=\"text-align:left\">x | y</td><td style=\"text-align:right\"></td></tr></tbody></table>")
    }
    @Test func pipeLineWithoutDelimiterIsParagraph() {
        #expect(MarkdownHTML.render("a | b\nc") == "<p>a | b c</p>")
    }
    @Test func nestedAndLooseLists() {
        #expect(MarkdownHTML.render("- a\n  - b\n- c") == "<ul><li>a\n<ul><li>b</li></ul></li><li>c</li></ul>")
        #expect(MarkdownHTML.render("1. a\n\n2. b") == "<ol><li><p>a</p></li><li><p>b</p></li></ol>")
        #expect(MarkdownHTML.render("3. a\n4. b").hasPrefix("<ol start=\"3\">"))
    }
    @Test func listItemWithCodeBlock() {
        #expect(MarkdownHTML.render("1. a\n\n   ```\n   x\n   ```\n2. b").contains("<pre><code>x</code></pre>"))
    }
    @Test func taskList() {
        let h = MarkdownHTML.render("- [x] done\n- [ ] todo")
        #expect(h.contains("<li class=\"task\"><input type=\"checkbox\" disabled checked> done</li>"))
        #expect(h.contains("<input type=\"checkbox\" disabled> todo"))
    }
    @Test func fenceLanguageTildeAndIndentedCode() {
        #expect(MarkdownHTML.render("~~~swift\nlet a\n~~~") == "<pre><code class=\"language-swift\">let a</code></pre>")
        #expect(MarkdownHTML.render("    <x>\n    y") == "<pre><code>&lt;x&gt;\ny</code></pre>")
        #expect(MarkdownHTML.render("```\"><script>\nx\n```").contains("<script>") == false)
    }
    @Test func setextAndHeadingIds() {
        #expect(MarkdownHTML.render("Title\n===\n\nSub\n---") == "<h1 id=\"title\">Title</h1>\n<h2 id=\"sub\">Sub</h2>")
        #expect(MarkdownHTML.render("## A & B ##\n## A & B") == "<h2 id=\"a--b\">A &amp; B</h2>\n<h2 id=\"a--b-1\">A &amp; B</h2>")
    }
    @Test func linksTitlesAndReferences() {
        #expect(MarkdownHTML.render("[a](http://e.com \"T\")") == "<p><a href=\"http://e.com\" title=\"T\">a</a></p>")
        #expect(MarkdownHTML.render("[a][x] [x] ![i][x]\n\n[X]: http://e.com \"T\"")
            == "<p><a href=\"http://e.com\" title=\"T\">a</a> <a href=\"http://e.com\" title=\"T\">x</a> <img alt=\"i\" src=\"http://e.com\" title=\"T\"></p>")
        #expect(MarkdownHTML.inline("[nope]") == "[nope]")
        #expect(MarkdownHTML.render("[a][x]\n\n[x]: javascript:alert(1)").contains("href=\"#\""))
    }
    @Test func imagesWithTitleAndLinked() {
        #expect(MarkdownHTML.inline("[![b](https://i/b.svg)](https://l.com)")
            == "<a href=\"https://l.com\"><img alt=\"b\" src=\"https://i/b.svg\"></a>")
        #expect(MarkdownHTML.inline("![a](p.png \"t\")") == "<img alt=\"a\" src=\"p.png\" title=\"t\">")
    }
    @Test func autolinks() {
        #expect(MarkdownHTML.inline("see https://e.com/a.") == "see <a href=\"https://e.com/a\">https://e.com/a</a>.")
        #expect(MarkdownHTML.inline("<https://e.com>") == "<a href=\"https://e.com\">https://e.com</a>")
        #expect(MarkdownHTML.inline("<a@b.co>") == "<a href=\"mailto:a@b.co\">a@b.co</a>")
        #expect(MarkdownHTML.inline("[https://e.com](https://e.com)") == "<a href=\"https://e.com\">https://e.com</a>")
    }
    @Test func hardBreakEscapesAndTags() {
        #expect(MarkdownHTML.render("a  \nb\\\nc") == "<p>a<br>b<br>c</p>")
        #expect(MarkdownHTML.inline("\\*x\\* \\<b>") == "*x* &lt;b&gt;")
        #expect(MarkdownHTML.inline("press <kbd>Ctrl</kbd><br>") == "press <kbd>Ctrl</kbd><br>")
        #expect(MarkdownHTML.inline("<b onclick=x>") == "&lt;b onclick=x&gt;")
        #expect(MarkdownHTML.inline("***x*** ~~y~~") == "<strong><em>x</em></strong> <del>y</del>")
    }
    @Test func footnotes() {
        let h = MarkdownHTML.render("a[^1] b[^nope]\n\n[^1]: note *text*")
        #expect(h.contains("<sup id=\"fnref-1\"><a href=\"#fn-1\">1</a></sup> b[^nope]"))
        #expect(h.contains("<li id=\"fn-1\">note <em>text</em> <a href=\"#fnref-1\">"))
    }
    @Test func alertsCommentsAndDetails() {
        #expect(MarkdownHTML.render("> [!WARNING]\n> careful") == "<div class=\"alert alert-warning\"><p class=\"alert-title\">Warning</p><p>careful</p></div>")
        #expect(MarkdownHTML.render("<!-- hidden\nmore -->\ntext") == "<p>text</p>")
        #expect(MarkdownHTML.render("<details>\n<summary>S *x*</summary>\n\nbody\n\n</details>")
            == "<details>\n<summary>S <em>x</em></summary>\n<p>body</p>\n</details>")
    }
    @Test func pageAllowsRemoteImagesOnly() {
        let p = MarkdownHTML.page("x")
        #expect(p.contains("img-src file: https:") && !p.contains("http:;"))
    }
}
