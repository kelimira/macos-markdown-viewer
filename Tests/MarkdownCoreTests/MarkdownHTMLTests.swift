import Testing
@testable import MarkdownCore

struct MarkdownHTMLTests {
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
}
