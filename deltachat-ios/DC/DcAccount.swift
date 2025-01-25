import Foundation

/// Represents [dc_accounts_t](https://c.delta.chat/classdc__accounts__t.html)
public class DcAccounts {
    public static let shared = DcAccounts()

    /// The application group identifier defines a group of apps or extensions that have access to a shared container.
    /// The ID is created in the apple developer portal and can be changed there.
    let applicationGroupIdentifier = "group.chat.delta.ios"
    var accountsPointer: OpaquePointer?
    var rpcPointer: OpaquePointer?
    public var fetchSemaphore: DispatchSemaphore?

    private var encryptedDatabases: [Int: Bool] = [:]
    private var freshlyAddedAccountIds: [Int] = []

    public init() {}

    deinit {
        closeDatabase()
    }

    public func migrate(dbLocation: String) -> Int {
        return Int(dc_accounts_migrate_account(accountsPointer, dbLocation))
    }

    public func add() -> Int {
        let accountId = Int(dc_accounts_add_account(accountsPointer))
        get(id: accountId).setConfig("verified_one_on_one_chats", "1")
        freshlyAddedAccountIds.append(accountId)
        return accountId
    }

    public func get(id: Int) -> DcContext {
        let contextPointer = dc_accounts_get_account(accountsPointer, UInt32(id))
        return DcContext(contextPointer: contextPointer)
    }

    public func isFreshlyAdded(id: Int) -> Bool {
        return freshlyAddedAccountIds.contains(id)
    }

    public func getAll() -> [Int] {
        let cAccounts = dc_accounts_get_all(accountsPointer)
        return DcUtils.copyAndFreeArray(inputArray: cAccounts)
    }

    public func getAllSorted() -> [Int] {
        return getAll().sorted { a, b in
            // no need to check for equality as sorted() is guaranteed to be stable;
            // meaning it preserves the relative order of elements that compare as equal here
            let orderA = get(id: a).getConfigInt("ui.ios.account_order"), orderB = get(id: b).getConfigInt("ui.ios.account_order")
            return orderA > orderB
        }
    }

    public func moveToTop(id: Int) {
        let maxOrder = getAll()
            .compactMap { get(id: $0).getConfigInt("ui.ios.account_order") }
            .max() ?? 0
        get(id: id).setConfigInt("ui.ios.account_order", maxOrder + 1)
    }

    public func getSelected() -> DcContext {
        let cPtr = dc_accounts_get_selected_account(accountsPointer)
        return DcContext(contextPointer: cPtr)
    }

    // call maybeNetwork() from a worker thread.
    public func maybeNetwork() {
        dc_accounts_maybe_network(accountsPointer)
    }

    public func maybeNetworkLost() {
        dc_accounts_maybe_network_lost(accountsPointer)
    }

    public func startIo() {
        if UserDefaults.nseFetching {
            // Wait for NSE-fetch to terminate before starting main-IO (both keep state unsynced, running at the same time would mess things up).
            // The other way round, NSE is not started when main-IO is running.
            NotificationCenter.default.post(name: Event.connectivityChanged, object: nil) // additional events needed as state changed outside mainapp
            startOrReschedule()
            func startOrReschedule() {
                if UserDefaults.mainIoRunning {
                    logger.info("➡️ wait for NSE to terminate")
                    if UserDefaults.nseFetching {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: startOrReschedule)
                    } else {
                        dc_accounts_start_io(accountsPointer)
                        NotificationCenter.default.post(name: Event.messagesChanged, object: nil, userInfo: ["message_id": Int(0), "chat_id": Int(0)])
                    }
                }
            }
        } else {
            dc_accounts_start_io(accountsPointer)
        }
    }

    public func stopIo() {
        dc_accounts_stop_io(accountsPointer)
    }

    public func restartIO() {
        stopIo()
        startIo()
    }

    public func backgroundFetch(timeout: UInt64) -> Bool {
        return dc_accounts_background_fetch(accountsPointer, timeout) == 1
    }

    public func setPushToken(token: String) {
        dc_accounts_set_push_device_token(accountsPointer, token)
    }

    public func select(id: Int) -> Bool {
        return dc_accounts_select_account(accountsPointer, UInt32(id)) == 1
    }

    public func remove(id: Int) -> Bool {
        encryptedDatabases[id] = nil
        return dc_accounts_remove_account(accountsPointer, UInt32(id)) == 1
    }

    public func getEventEmitter() -> DcEventEmitter {
        let eventEmitterPointer = dc_accounts_get_event_emitter(accountsPointer)
        return DcEventEmitter(eventEmitterPointer: eventEmitterPointer)
    }

    public func openDatabase(writeable: Bool) {
        if var sharedDbLocation = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier) {
            sharedDbLocation.appendPathComponent("accounts", isDirectory: true)
            accountsPointer = dc_accounts_new(sharedDbLocation.path, writeable ? 1 : 0)

            for accountId in getAll() {
                let dcContext = get(id: accountId)
                dcContext.setConfig("verified_one_on_one_chats", "1")
            }

            rpcPointer = dc_jsonrpc_init(accountsPointer)
        }
    }

    public func closeDatabase() {
        if rpcPointer != nil {
            dc_jsonrpc_unref(rpcPointer)
            rpcPointer = nil
        }

        if accountsPointer != nil {
            dc_accounts_unref(accountsPointer)
            accountsPointer = nil
        }
    }

    public func getFreshMessageCount(skipCurrent: Bool = false) -> Int {
        var freshCount = 0
        let skipId = skipCurrent ? getSelected().id : -1
        for accountId in getAll() {
            if accountId != skipId {
                let dcContext = get(id: accountId)
                if !dcContext.isMuted() {
                    freshCount += dcContext.getFreshMessagesCount()
                }
            }
        }
        return freshCount
    }

    @discardableResult
    public func blockingCall(method: String, params: [AnyObject]) -> Data? {
        if let paramsData = try? JSONSerialization.data(withJSONObject: params),
           let paramsStr = String(data: paramsData, encoding: .utf8) {
            let inStr = "{\"jsonrpc\":\"2.0\", \"method\":\"\(method)\", \"params\":\(paramsStr), \"id\":1}"
            if let outCStr = dc_jsonrpc_blocking_call(rpcPointer, inStr) {
                let outStr = String(cString: outCStr)
                dc_str_unref(outCStr)
                return outStr.data(using: .utf8)
            }
        }
        return nil
    }
}
