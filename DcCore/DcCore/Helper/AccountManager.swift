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

    private func getUniqueDbName() -> String? {
        let filemanager = FileManager.default
        let databaseHelper = DatabaseHelper()
        if databaseHelper.updateSucceeded(), let sharedDir = databaseHelper.sharedDir {
            var index = 1
            while true {
                let test = String(format: "messenger-%d.db", index)
                let testBlobdir = String(format: "messenger-%d.db-blobs", index)
                if !filemanager.fileExists(atPath: sharedDir.appendingPathComponent(test).path) &&
                   !filemanager.fileExists(atPath: sharedDir.appendingPathComponent(testBlobdir).path) {
                    return test
                }
                index += 1
            }
        }
        return nil
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
        // create an empty DcContext object - this will be set up then, starting with
        // getSelectedAccount()

        // TODO
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
    public func beginAccountCreation() -> Bool {
        guard let userDefaults = UserDefaults.shared else { return false }

        let prevDbName = userDefaults.string(forKey: UserDefaults.currAccountDbName) ?? defaultDbName
        guard let inCreationDbName = getUniqueDbName() else { return false }

        userDefaults.set(prevDbName, forKey: UserDefaults.prevAccountDbName)
        userDefaults.set(inCreationDbName, forKey: UserDefaults.currAccountDbName)

        resetDcContext()
        return true
    }
}
