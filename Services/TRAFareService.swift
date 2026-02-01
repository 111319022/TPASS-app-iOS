import Foundation
import SQLite3

class TRAFareService {
    static let shared = TRAFareService()
    var db: OpaquePointer?

    init() {
        setupDatabase()
    }

    private func setupDatabase() {
        if let path = Bundle.main.path(forResource: "TRA_Fares_Fixed", ofType: "sqlite") {
            if sqlite3_open(path, &db) != SQLITE_OK {
                print("無法開啟台鐵資料庫")
            }
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
