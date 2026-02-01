import json
import os

# 1. 設定你的 JSON 檔名 (請確認這裡跟你的檔名一樣)
input_json = 'Data/TRAStations.json'
output_swift = 'TRAStationData.swift'

print(f"正在讀取 {input_json}...")

try:
    with open(input_json, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
        # 處理 TDX 回傳結構 (有時候是直接 List，有時候在 "Stations" key 裡面)
        stations = data.get('Stations', []) if isinstance(data, dict) else data
        
        # 根據 StationID 排序 (轉成數字排比較準)
        stations.sort(key=lambda x: int(x.get('StationID', '9999')) if x.get('StationID', '').isdigit() else 9999)

        print(f"找到 {len(stations)} 個車站，正在轉換...")

        with open(output_swift, 'w', encoding='utf-8') as out:
            # 寫入 Swift 檔頭
            out.write('import Foundation\n\n')
            out.write('struct TRAStation: Identifiable, Hashable {\n')
            out.write('    let id: String\n')
            out.write('    let name: String\n')
            out.write('}\n\n')
            out.write('class TRAStationData {\n')
            out.write('    static let shared = TRAStationData()\n\n')
            out.write('    // 自動生成的全台車站清單\n')
            out.write('    let allStations: [TRAStation] = [\n')

            # 迴圈寫入資料
            for st in stations:
                sid = st.get('StationID')
                # 取得中文站名
                name = st.get('StationName', {}).get('Zh_tw', 'Unknown')
                
                if sid and name:
                    out.write(f'        TRAStation(id: "{sid}", name: "{name}"),\n')

            # 寫入檔尾
            out.write('    ]\n\n')
            out.write('    func getStationName(id: String) -> String {\n')
            out.write('        return allStations.first { $0.id == id }?.name ?? id\n')
            out.write('    }\n')
            out.write('}\n')

    print(f"✅ 成功產生 {output_swift}！")
    print("請把這個檔案拖進 Xcode 使用。")

except Exception as e:
    print(f"❌ 發生錯誤: {e}")
