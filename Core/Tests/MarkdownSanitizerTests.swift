import Testing
@testable import Core

struct MarkdownSanitizerTests {

    @Test func allowedCDNImageKeptVerbatim() {
        let md = "![pic](https://cdn.atsu.moe/img/cover.webp)"
        #expect(MarkdownSanitizer.sanitizeImages(md) == md)
    }

    @Test func allowedApexImageKept() {
        let md = "![pic](https://atsu.moe/img/cover.webp)"
        #expect(MarkdownSanitizer.sanitizeImages(md) == md)
    }

    @Test func hostileHostDemotedToLink() {
        let sanitized = MarkdownSanitizer.sanitizeImages("![pixel](https://attacker.com/pixel.png)")
        #expect(sanitized == "[pixel](https://attacker.com/pixel.png)")
        #expect(!sanitized.contains("!["))
    }

    @Test func allowedSubdomainKept() {
        let md = "![pic](https://www.atsu.moe/a.png)"
        #expect(MarkdownSanitizer.sanitizeImages(md) == md)
    }

    @Test func similarHostNotKept() {
        let sanitized = MarkdownSanitizer.sanitizeImages("![x](https://notatsu.moe.ru/a.png)")
        #expect(sanitized == "[x](https://notatsu.moe.ru/a.png)")
    }

    @Test func malformedURLDemoted() {
        let sanitized = MarkdownSanitizer.sanitizeImages("![x](notaurl%)")
        #expect(sanitized == "[x](notaurl%)")
    }

    @Test func noImagesUnchanged() {
        let md = "Just **text** with [a link](https://example.com)"
        #expect(MarkdownSanitizer.sanitizeImages(md) == md)
    }

    @Test func mixedImagesHandled() {
        let sanitized = MarkdownSanitizer.sanitizeImages(
            "![ok](https://cdn.atsu.moe/a.png) text ![bad](https://evil.io/b.png) ![ok2](https://atsu.moe/c.png)"
        )
        #expect(sanitized.contains("![ok](https://cdn.atsu.moe/a.png)"))
        #expect(sanitized.contains("[bad](https://evil.io/b.png)"))
        #expect(sanitized.contains("![ok2](https://atsu.moe/c.png)"))
    }

    @Test func hostMatching() {
        #expect(MarkdownSanitizer.isAllowed(host: "atsu.moe"))
        #expect(MarkdownSanitizer.isAllowed(host: "cdn.atsu.moe"))
        #expect(MarkdownSanitizer.isAllowed(host: "sub.cdn.atsu.moe"))
        #expect(!MarkdownSanitizer.isAllowed(host: "evilstu.moe"))
        #expect(!MarkdownSanitizer.isAllowed(host: "atsu.moe.evil.com"))
    }
}
