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

    @Test func justNowRendersAsNowOrSeconds() {
        let label = Date().relativeLabel
        #expect(label == "now" || label.contains("econd"))
    }

    @Test func minutesAgoBucket() {
        #expect(Date(timeIntervalSinceNow: -120).relativeLabel.contains("minute"))
    }

    @Test func hoursAgoBucket() {
        #expect(Date(timeIntervalSinceNow: -7_200).relativeLabel.contains("hour"))
    }

    @Test func daysAgoBucket() {
        #expect(Date(timeIntervalSinceNow: -3 * 86_400).relativeLabel.contains("day"))
    }

    @Test func futureIsNotAgo() {
        let label = Date(timeIntervalSinceNow: 7_200).relativeLabel
        #expect(label.contains("hour"))
        #expect(!label.contains("ago"))
    }
}
