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
        #expect(MarkdownSanitizer.isAllowed(host: "CDN.ATSU.MOE"))
        #expect(!MarkdownSanitizer.isAllowed(host: "localhost"))
        #expect(!MarkdownSanitizer.isAllowed(host: "127.0.0.1"))
    }

    @Test func titleAttributeHostileImageDemoted() {
        let sanitized = MarkdownSanitizer.sanitizeImages(#"![x](https://evil.com/a.png "t")"#)
        #expect(sanitized == #"[x](https://evil.com/a.png)"#)
        #expect(!sanitized.contains("![x]"))
    }

    @Test func titleAttributeAllowedImageKept() {
        // The title attribute is dropped, but the image must remain an image on
        // the allowed host (not demoted) — that's the security property.
        let sanitized = MarkdownSanitizer.sanitizeImages(#"![x](https://cdn.atsu.moe/a.png "t")"#)
        #expect(sanitized.hasPrefix("!["))
        #expect(sanitized.contains("https://cdn.atsu.moe/a.png"))
    }

    @Test func referenceStyleImageDemoted() {
        let sanitized = MarkdownSanitizer.sanitizeImages("![alt][r]\n\n[r]: https://evil.com/r.png")
        #expect(sanitized.contains("[alt][r]"))
        #expect(!sanitized.contains("![alt][r]"))
    }

    @Test func nestedHostileImageFullyDemoted() {
        let sanitized = MarkdownSanitizer.sanitizeImages("![![a](https://evil.com/p.png)](https://evil.com/)")
        #expect(!sanitized.contains("![a]"))
        #expect(!sanitized.contains("![![a]"))
    }

    @Test func ftpSchemeDemoted() {
        let sanitized = MarkdownSanitizer.sanitizeImages("![x](ftp://cdn.atsu.moe/x.png)")
        #expect(sanitized == "[x](ftp://cdn.atsu.moe/x.png)")
    }

    @Test func spoilerWrappedImageSanitized() {
        let kept = MarkdownSanitizer.sanitizeImages("||![pic](https://cdn.atsu.moe/s.png)||")
        #expect(kept == "||![pic](https://cdn.atsu.moe/s.png)||")

        let demoted = MarkdownSanitizer.sanitizeImages("||![pixel](https://evil.com/p.png)||")
        #expect(demoted == "||[pixel](https://evil.com/p.png)||")
        #expect(!demoted.contains("!["))
    }
}
