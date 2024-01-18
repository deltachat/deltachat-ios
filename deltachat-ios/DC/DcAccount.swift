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
        return accountId
    }

    public func get(id: Int) -> DcContext {
        let contextPointer = dc_accounts_get_account(accountsPointer, UInt32(id))
        return DcContext(contextPointer: contextPointer)
    }

    public func getAll() -> [Int] {
        let cAccounts = dc_accounts_get_all(accountsPointer)
        return DcUtils.copyAndFreeArray(inputArray: cAccounts)
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

    public func isAllWorkDone() -> Bool {
        return dc_accounts_all_work_done(accountsPointer) != 0
    }

    public func startIo() {
        dc_accounts_start_io(accountsPointer)
    }

    public func stopIo() {
        dc_accounts_stop_io(accountsPointer)
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
        var version = ""
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            version += " " + appVersion
        }

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
                freshCount += get(id: accountId).getFreshMessages().count
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
