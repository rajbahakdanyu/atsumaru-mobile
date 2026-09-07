import Foundation
import Testing
@testable import Core

struct DateParsingTests {

    @Test func ISO8601ParsingAcceptsFractionalAndWholeSecondsAndRejectsGarbage() {
        #expect(DateParsing.epochMs(fromISO8601: "2026-06-10T00:03:06.716Z") == 1_781_049_786_716)
        #expect(DateParsing.epochMs(fromISO8601: "2026-06-10T00:03:06Z") == 1_781_049_786_000)
        #expect(DateParsing.epochMs(fromISO8601: "not-a-date") == nil)
    }

    @Test func epochZeroIsUnixEpoch() {
        #expect(0.dateFromEpochMs == Date(timeIntervalSince1970: 0))
    }

    @Test func wholeSecondEpochMsConvertsExactly() {
        #expect(1_600_000_000_000.dateFromEpochMs == Date(timeIntervalSince1970: 1_600_000_000))
        #expect(4_102_444_800_000.dateFromEpochMs == Date(timeIntervalSince1970: 4_102_444_800))
    }

    @Test func subSecondPrecisionPreserved() {
        let d = 1_725_283_204_567.dateFromEpochMs
        #expect(d != nil)
        #expect(abs((d?.timeIntervalSince1970 ?? 0) - 1_725_283_204.567) < 0.001)
    }

    @Test func negativeEpochMsIsBefore1970() {
        #expect((-1_000).dateFromEpochMs == Date(timeIntervalSince1970: -1))
        #expect((-86_400_000).dateFromEpochMs! < Date(timeIntervalSince1970: 0))
    }

    @Test func relativeLabelProducesLocalizedOutput() {
        #expect(!Date(timeIntervalSinceNow: -120).relativeLabel.isEmpty)
    }
}
