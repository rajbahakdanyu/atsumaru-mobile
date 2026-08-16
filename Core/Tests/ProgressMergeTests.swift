import Foundation
import Testing
@testable import Core

struct ProgressMergeTests {
    private func state(_ mangaId: String = "m", chapterId: String = "c", page: Int = 0, seconds: TimeInterval) -> ProgressState {
        ProgressState(mangaId: mangaId, chapterId: chapterId, pageIndex: page, updatedAt: Date(timeIntervalSince1970: seconds))
    }

    @Test func returnsRemoteWhenRemoteNewer() {
        let local = state(seconds: 100)
        let remote = state(page: 3, seconds: 200)
        let merged = ProgressMerge.merge(local: local, remote: remote)
        #expect(merged?.pageIndex == 3)
    }

    @Test func returnsLocalWhenLocalNewer() {
        let local = state(page: 5, seconds: 300)
        let remote = state(seconds: 200)
        let merged = ProgressMerge.merge(local: local, remote: remote)
        #expect(merged?.pageIndex == 5)
    }

    @Test func remoteWinsOnEqualTimestamps() {
        let local = state(page: 5, seconds: 100)
        let remote = state(page: 2, seconds: 100)
        let merged = ProgressMerge.merge(local: local, remote: remote)
        #expect(merged?.pageIndex == 2)
    }

    @Test func returnsLocalWhenRemoteNil() {
        let local = state(page: 4, seconds: 100)
        let merged = ProgressMerge.merge(local: local, remote: nil)
        #expect(merged?.pageIndex == 4)
    }

    @Test func returnsRemoteWhenLocalNil() {
        let remote = state(page: 7, seconds: 100)
        let merged = ProgressMerge.merge(local: nil, remote: remote)
        #expect(merged?.pageIndex == 7)
    }

    @Test func returnsNilWhenBothNil() {
        let merged = ProgressMerge.merge(local: nil, remote: nil)
        #expect(merged == nil)
    }
}