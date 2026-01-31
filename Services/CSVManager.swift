import Foundation
import SwiftData
import SwiftUI

class CSVManager {
    static let shared = CSVManager()
    
    // 定義 CSV 表頭 (使用英文欄位名，確保跨語言相容)
    private let header = "id,date,type,startStation,endStation,price,paidPrice,isTransfer,isFree,routeId,note"
    
    // 日期格式設定 (固定格式，避免受使用者手機地區設定影響)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // MARK: - 匯出 (Export)
    func generateCSV(from trips: [Trip]) -> String {
        var csvString = header + "\n"
        
        for trip in trips {
            let dateStr = dateFormatter.string(from: trip.createdAt)
            // 處理備註中的逗號與換行，用引號包起來
            let cleanNote = "\"\(trip.note.replacingOccurrences(of: "\"", with: "\"\""))\""
            
            let row = [
                trip.id,
                dateStr,
                trip.type.rawValue, // 儲存 rawValue (英文代碼) 比較安全
                trip.startStation,
                trip.endStation,
                String(trip.originalPrice),
                String(trip.paidPrice),
                trip.isTransfer ? "1" : "0",
                trip.isFree ? "1" : "0",
                trip.routeId,
                cleanNote
            ].joined(separator: ",")
            
            csvString.append(row + "\n")
        }
        
        return csvString
    }
    
    // MARK: - 匯入 (Import)
    @MainActor
    func importCSV(url: URL, context: ModelContext, userId: String) throws -> Int {
        // 1. 讀取檔案內容
        // 嘗試用 UTF-8 讀取，如果失敗嘗試用 ASCII (避免編碼問題)
        let content = try String(contentsOf: url, encoding: .utf8)
        
        var rows = content.components(separatedBy: .newlines)
        
        // 移除標題列
        if !rows.isEmpty && rows[0].hasPrefix("id,date") {
            rows.removeFirst()
        }
        
        var successCount = 0
        
        // 2. 解析每一行
        for row in rows where !row.isEmpty {
            let columns = parseCSVRow(row)
            
            // 確保欄位數量正確 (至少要有 11 個欄位)
            guard columns.count >= 11 else { continue }
            
            let id = columns[0]
            
            // 🔥 檢查重複：如果資料庫已經有這個 ID，就跳過 (或是你可以選擇更新)
            let descriptor = FetchDescriptor<Trip>(predicate: #Predicate { $0.id == id })
            if let existingCount = try? context.fetchCount(descriptor), existingCount > 0 {
                print("⚠️ 跳過重複資料: \(id)")
                continue
            }
            
            // 解析資料
            guard let date = dateFormatter.date(from: columns[1]),
                  let type = TransportType(rawValue: columns[2]),
                  let originalPrice = Int(columns[5]),
                  let paidPrice = Int(columns[6])
            else {
                print("❌ 資料解析失敗: \(row)")
                continue
            }
            
            let isTransfer = (columns[7] == "1" || columns[7].lowercased() == "true")
            let isFree = (columns[8] == "1" || columns[8].lowercased() == "true")
            
            // 處理備註的引號還原
            let note = columns[10].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            
            // 3. 建立 SwiftData 物件
            let newTrip = Trip(
                id: id, // 使用 CSV 裡的舊 ID，確保資料一致性
                userId: userId, // 使用當前登入用戶的 ID
                createdAt: date,
                type: type,
                originalPrice: originalPrice,
                paidPrice: paidPrice,
                isTransfer: isTransfer,
                isFree: isFree,
                startStation: columns[3],
                endStation: columns[4],
                routeId: columns[9],
                note: note
            )
            
            context.insert(newTrip)
            successCount += 1
        }
        
        // 4. 儲存
        try context.save()
        return successCount
    }
    
    // 簡單的 CSV 行解析器 (處理引號內的逗號)
    private func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false
        
        for char in row {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }
}
