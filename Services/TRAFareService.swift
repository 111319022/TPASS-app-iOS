import Foundation
import SQLite3

@MainActor
class TRAFareService {
    static let shared = TRAFareService()
    var db: OpaquePointer?

    // 🔥 1. 新增這個 Helper 屬性，用來自動切換 Bundle
    var currentBundle: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module  // 給 Swift Playgrounds 用
        #else
        return Bundle.main    // 給一般 Xcode 專案用
        #endif
    }

    init() {
        setupDatabase()
    }

    private func setupDatabase() {
        // 🔥 2. 修改這裡：把 Bundle.main 改成 self.currentBundle
        if let path = currentBundle.path(forResource: "TRA_Fares_Fixed", ofType: "sqlite") {
            if sqlite3_open(path, &db) != SQLITE_OK {
                print("❌ 無法開啟台鐵資料庫，路徑：\(path)")
            } else {
                print("✅ 台鐵資料庫載入成功")
            }
        } else {
            print("❌ 找不到 TRA_Fares_Fixed.sqlite 檔案！請確認是否已複製到 Package 內")
        }
    }

    func getFare(from originID: String, to destID: String) -> Int {
        let query = "SELECT price FROM fares WHERE origin_id = ? AND dest_id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (originID as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (destID as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                let price = sqlite3_column_int(statement, 0)
                sqlite3_finalize(statement)
                return Int(price)
            }
        }
        sqlite3_finalize(statement)
        return 0
    }
}
