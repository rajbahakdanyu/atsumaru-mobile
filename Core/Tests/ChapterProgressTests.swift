import Foundation
import Testing
@testable import Core

@Suite struct ChapterProgressTests {
    @Test func isCompleteUsesFracAndPages() {
        #expect(ChapterProgress(page: 5, pages: 5, frac: 1).isComplete)
        #expect(ChapterProgress(page: 4, pages: 5, frac: 0.98).isComplete)  // off-by-one rounding tolerance
        #expect(!ChapterProgress(page: 2, pages: 5, frac: 0.4).isComplete)
        #expect(!ChapterProgress(page: nil, pages: nil, frac: nil).isComplete)
    }

    @Test func fractionFallsBackToPages() {
        #expect(ChapterProgress(page: 3, pages: 10, frac: nil).fraction == 0.3)
        #expect(ChapterProgress(page: 5, pages: 5, frac: 0.9).fraction == 0.9)
        #expect(ChapterProgress(page: nil, pages: nil, frac: nil).fraction == 0)
    }
}
