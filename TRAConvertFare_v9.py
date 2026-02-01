import json
import sqlite3
import os

# 1. 設定檔案名稱
input_json = 'TRA_Final.json' 
output_db = 'TRA_Fares_Fixed.sqlite'

print(f"🚀 啟動 V9 強制去重版，正在讀取 {input_json}...")

# 2. 建立資料庫
if os.path.exists(output_db):
    os.remove(output_db)

conn = sqlite3.connect(output_db)
cursor = conn.cursor()
cursor.execute('CREATE TABLE fares (origin_id TEXT, dest_id TEXT, price INTEGER)')

try:
    with open(input_json, 'r', encoding='utf-8-sig') as f:
        data = json.load(f)
        fares_list = data if isinstance(data, list) else []

        print(f"📊 讀取成功，共有 {len(fares_list)} 筆原始資料。")

        # --- 步驟 A: 使用字典進行去重 (Key: 起迄站 -> Value: 最低價格) ---
        # 這是解決「破千」問題的關鍵！
        unique_fares = {} 
        target_code = 6  # 鎖定區間車代碼

        print("🔄 正在掃描並過濾最低價...")
        
        for item in fares_list:
            origin = str(item.get('startStaCode', ''))
            dest = str(item.get('endStaCode', ''))
            
            details = item.get('details', [])
            for d in details:
                # 只看我們鎖定的代碼 6
                if d.get('trnclassCode') == target_code:
                    price = d.get('adultTktPrice')
                    
                    if price is not None:
                        # 生成唯一的 Key
                        route_key = (origin, dest)
                        
                        # 核心邏輯：如果這條路線還沒存過，或是新價格比舊價格便宜 -> 更新它
                        # 這會直接把 1327 這種怪價格踢掉，只留 62
                        if route_key not in unique_fares or price < unique_fares[route_key]:
                            unique_fares[route_key] = price
                        
                    # 找到代碼 6 之後就換下一筆 (因為同一筆 entry 裡通常只有一個 code 6)
                    break 

        # --- 步驟 B: 寫入資料庫 ---
        print(f"📝 正在寫入 {len(unique_fares)} 筆精簡後的資料...")
        
        batch_data = []
        for (origin, dest), price in unique_fares.items():
            batch_data.append((origin, dest, price))
            
        cursor.executemany('INSERT INTO fares VALUES (?, ?, ?)', batch_data)
        conn.commit()

        # --- 步驟 C: 最終驗證 ---
        cursor.execute("SELECT price FROM fares WHERE origin_id='1000' AND dest_id='0900'")
        check_kl = cursor.fetchone()
        
        cursor.execute("SELECT price FROM fares WHERE origin_id='1000' AND dest_id='1030'")
        check_yg = cursor.fetchone()

        print(f"\n🎉 完美成功！")
        print(f"➤ 台北->基隆 最終價格: ${check_kl[0] if check_kl else '未找到'} (不應該是 1327)")
        print(f"➤ 台北->鶯歌 最終價格: ${check_yg[0] if check_yg else '未找到'} (不應該是 1343)")
        print(f"➤ 請將 {output_db} 拖入 Xcode 取代舊檔！")

except Exception as e:
    print(f"❌ 發生錯誤: {e}")
finally:
    conn.close()