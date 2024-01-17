//
//  DcBackupProvider.swift
//  DcCore
//
//  Created by Nathan Mattes on 17.01.24.
//  Copyright © 2024 merlinux GmbH. All rights reserved.
//

import Foundation

/// Set up another device
///
/// See [dc_backup_provider_t Class Reference](https://c.delta.chat/classdc__backup__provider__t.html)
public class DcBackupProvider {
    private var dcBackupProviderPointer: OpaquePointer?

    public init(_ dcContext: DcContext) {
        dcBackupProviderPointer = dc_backup_provider_new(dcContext.contextPointer)
    }

    deinit {
        unref()
    }

    public func isOk() -> Bool {
        return dcBackupProviderPointer != nil
    }

    public func unref() {
        if dcBackupProviderPointer != nil {
            dc_backup_provider_unref(dcBackupProviderPointer)
            dcBackupProviderPointer = nil
        }
    }

    public func getQr() -> String? {
        guard let cString = dc_backup_provider_get_qr(dcBackupProviderPointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func getQrSvg() -> String? {
        guard let cString = dc_backup_provider_get_qr_svg(dcBackupProviderPointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func wait() {
        dc_backup_provider_wait(dcBackupProviderPointer)
    }
 }
