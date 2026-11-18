import Testing
@testable import MarkdownCore

struct MarkdownHTMLTests {
    @Test func externalLinkPolicy() {
        for ok in ["http://a.com", "HTTPS://a.com", "mailto:a@b.c"] { #expect(MarkdownHTML.isExternallyOpenable(URL(string: ok)!)) }
        for bad in ["file:///x/run.command", "x-apple.systempreferences:", "javascript:1"] { #expect(!MarkdownHTML.isExternallyOpenable(URL(string: bad)!)) }
    }

    @Test func headingAndParagraph() {
        #expect(MarkdownHTML.render("# Hi\n\nsome *text*\nmore") == "<h1>Hi</h1>\n<p>some <em>text</em> more</p>")
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
        #expect(p.contains("<h1>T</h1>") && p.contains("Content-Security-Policy"))
    }
}
