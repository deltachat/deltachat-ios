import ActivityKit
import DcCore

struct WebxdcLiveActivityAttributes: ActivityAttributes {
    typealias ContentState = WebxdcInfo

    let contextId: Int
    let messageId: Int
}
