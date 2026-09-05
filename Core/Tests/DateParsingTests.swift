import Foundation
import Testing
@testable import Core

struct DateParsingTests {

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

    // relativeLabel formats with the host locale, so these assert on bucket
    // differentiation between offsets instead of English wording.
    @Test func justNowDiffersFromMinutesBucket() {
        let now = Date().relativeLabel
        #expect(!now.isEmpty)
        #expect(now != Date(timeIntervalSinceNow: -120).relativeLabel)
    }

    @Test func minutesAgoBucket() {
        let label = Date(timeIntervalSinceNow: -120).relativeLabel
        #expect(!label.isEmpty)
        #expect(label != Date(timeIntervalSinceNow: -30).relativeLabel)
        #expect(label != Date(timeIntervalSinceNow: -7_200).relativeLabel)
    }

    @Test func hoursAgoBucket() {
        let label = Date(timeIntervalSinceNow: -7_200).relativeLabel
        #expect(!label.isEmpty)
        #expect(label != Date(timeIntervalSinceNow: -120).relativeLabel)
        #expect(label != Date(timeIntervalSinceNow: -3 * 86_400).relativeLabel)
    }

    @Test func daysAgoBucket() {
        let label = Date(timeIntervalSinceNow: -3 * 86_400).relativeLabel
        #expect(!label.isEmpty)
        #expect(label != Date(timeIntervalSinceNow: -7_200).relativeLabel)
    }

    @Test func futureIsNotAgo() {
        #expect(Date(timeIntervalSinceNow: 7_200).relativeLabel
            != Date(timeIntervalSinceNow: -7_200).relativeLabel)
    }
}
