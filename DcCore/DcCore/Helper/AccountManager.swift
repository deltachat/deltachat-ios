import Foundation

public class Account {
    private let dbName: String
    public let displayname: String
    public let addr: String
    public let configured: Bool
    public let current: Bool

    public init(dbName: String, displayname: String, addr: String, configured: Bool) {
        self.dbName = dbName
        self.displayname = displayname
        self.addr = addr
        self.configured = configured
        self.current = false
    }
}

public class AccountManager {

    private let defaultDbName = "messenger.db"

    public init() {
    }

    private func maybeGetAccount(dbFile: String) -> Account? {
        let testContext = DcContext()
        testContext.openDatabase(dbFile: dbFile)
        if !testContext.isOk() {
            return nil
        }

        return Account(dbName: dbFile,
                       displayname: testContext.getConfig("displayname") ?? "",
                       addr: testContext.getConfig("addr") ?? "",
                       configured: testContext.isConfigured())
    }

    private func resetDcContext() {

    }


    // MARK: - public api

    // get a list of all accounts available or an empty array on errors
    // (eg. when the shared dir is empty due to out-of-space on updateDatabaseLocation()-migration)
    public func getAccounts() -> [Account] {
        var result: [Account] = Array()
        do {
            let databaseHelper = DatabaseHelper()
            if databaseHelper.updateSucceeded(), let sharedDir = databaseHelper.sharedDir {
                let names = try FileManager.default.contentsOfDirectory(atPath: sharedDir.path)
                for name in names {
                    if name.hasPrefix("messenger") && name.hasSuffix(".db") {
                        let dbFile = sharedDir.appendingPathComponent(name).path
                        if let account = maybeGetAccount(dbFile: dbFile) {
                            result.append(account)
                        }
                    }
                }
            }
        } catch {
            DcContext.shared.logger?.error("Could not iterate through sharedDir.")
        }
        return result
    }

    public func getSelectedAccount() -> String {
        let databaseHelper = DatabaseHelper()
        if databaseHelper.updateSucceeded(), let sharedDir = databaseHelper.sharedDir {
            if let userDefaults = UserDefaults.shared {
                let name = userDefaults.string(forKey: UserDefaults.currAccountDbName) ?? defaultDbName
                return sharedDir.appendingPathComponent(name).path
            }
        }
        // error, usefallback
        return databaseHelper.currentDatabaseLocation
    }

    // pause the current account and let the user create a new one.
    // this function is not needed on the very first account creation.
    public func beginAccountCreation() {
        resetDcContext()
    }
}
