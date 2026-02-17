import Foundation
import SwiftData
import SwiftUI

class CSVManager {
    @MainActor static let shared = CSVManager()
    
    // 定義 CSV 表頭 (使用英文欄位名，確保跨語言相容)
    private let header = "id,date,type,startStation,endStation,price,paidPrice,isTransfer,isFree,routeId,note,transferDiscountType,cycleId"
    
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
                cleanNote,
                trip.transferDiscountType?.rawValue ?? "", //     新增：轉乘優惠類型
                trip.cycleId ?? "" //     新增：週期 ID
            ].joined(separator: ",")
            
            csvString.append(row + "\n")
        }
        
        return csvString
    }
    
    // MARK: - 匯入 (Import)
    @MainActor
    func importCSV(url: URL, context: ModelContext, userId: String, userCycles: [Cycle]) throws -> (imported: Int, invalidCycles: Int) {
        // 1. 讀取檔案內容
        // 嘗試用 UTF-8 讀取，如果失敗嘗試用 ASCII (避免編碼問題)
        let content = try String(contentsOf: url, encoding: .utf8)
        
        var rows = parseCSVContent(content)
        
        // 移除標題列
        if let firstRow = rows.first, firstRow.count >= 2, firstRow[0] == "id", firstRow[1] == "date" {
            rows.removeFirst()
        }
        
        var successCount = 0
        var invalidCycleCount = 0
        
        // 2. 解析每一行
        for columns in rows where !columns.isEmpty {
            
            // 🔧 向後兼容：支援舊格式（11 欄位）和新格式（13 欄位）
            guard columns.count >= 11 else { continue }
            
            let id = columns[0]
            
            //     檢查重複：如果資料庫已經有這個 ID，就跳過 (或是你可以選擇更新)
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
                print("❌ 資料解析失敗: \(columns)")
                continue
            }
            
            let isTransfer = (columns[7] == "1" || columns[7].lowercased() == "true")
            let isFree = (columns[8] == "1" || columns[8].lowercased() == "true")
            
            // 處理備註的引號還原
            let note = columns[10]
            
            //     新增：解析轉乘優惠類型和週期 ID（向後兼容舊格式）
            var transferDiscountType: TransferDiscountType? = nil
            var cycleId: String? = nil
            
            if columns.count >= 12 {
                let transferTypeRaw = columns[11].trimmingCharacters(in: .whitespaces)
                if !transferTypeRaw.isEmpty {
                    transferDiscountType = TransferDiscountType(rawValue: transferTypeRaw)
                }
            }
            
            if columns.count >= 13 {
                let cycleIdRaw = columns[12].trimmingCharacters(in: .whitespaces)
                if !cycleIdRaw.isEmpty {
                    // 🔧 檢查 cycleId 是否存在於當前用戶的週期列表中
                    if userCycles.contains(where: { $0.id == cycleIdRaw }) {
                        cycleId = cycleIdRaw
                    } else {
                        // 週期不存在，設為 nil 讓系統自動推論
                        cycleId = nil
                        invalidCycleCount += 1
                        print("⚠️ Cycle ID \(cycleIdRaw) not found, will auto-resolve for trip \(id)")
                    }
                }
            }
            
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
                note: note,
                transferDiscountType: transferDiscountType,
                cycleId: cycleId
            )
            
            context.insert(newTrip)
            successCount += 1
        }
        
        // 4. 儲存
        try context.save()
        return (imported: successCount, invalidCycles: invalidCycleCount)
    }
    
    // CSV 內容解析器：支援引號、逗號與換行
    private func parseCSVContent(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        let chars = Array(content)
        var index = 0
        
        while index < chars.count {
            let char = chars[index]
            
            if char == "\"" {
                if insideQuotes, index + 1 < chars.count, chars[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                row.append(field)
                field = ""
            } else if (char == "\n" || char == "\r") && !insideQuotes {
                row.append(field)
                field = ""
                if !row.isEmpty {
                    rows.append(row)
                }
                row = []
                if char == "\r", index + 1 < chars.count, chars[index + 1] == "\n" {
                    index += 1
                }
            } else {
                field.append(char)
            }
            
            index += 1
        }
        
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        
        return rows
    }
}
