import Foundation

public enum ProgressMerge {
    public static func merge(local: ProgressState?, remote: ProgressState?) -> ProgressState? {
        switch (local, remote) {
        case let (l?, r?): return r.updatedAt >= l.updatedAt ? r : l
        case let (l?, nil): return l
        case let (nil, r?): return r
        case (nil, nil): return nil
        }
    }
}