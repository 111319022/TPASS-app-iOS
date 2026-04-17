import csv
import json
import os

def convert_mrt_fare_csv_to_json(csv_filename, json_filename):
    fare_data = {}
    
    if not os.path.exists(csv_filename):
        print(f"❌ 找不到檔案：{csv_filename}")
        return

    # 台灣政府開放資料常見的編碼清單
    encodings_to_try = ['cp950', 'big5', 'utf-8', 'utf-8-sig']
    
    for encoding in encodings_to_try:
        try:
            # 嘗試用不同的編碼開啟檔案
            with open(csv_filename, mode='r', encoding=encoding) as file:
                reader = csv.DictReader(file)
                
                # 測試是否能正確讀取第一行
                for row in reader:
                    origin = row['起站'].strip()
                    destination = row['訖站'].strip()
                    fare = int(row['全票票價[金額]'])
                    
                    if origin not in fare_data:
                        fare_data[origin] = {}
                    
                    fare_data[origin][destination] = fare
            
            # 如果上面都沒報錯，代表編碼猜對了！
            print(f"✅ 成功以 {encoding} 編碼讀取 CSV 檔案！")
            break # 跳出嘗試迴圈
            
        except UnicodeDecodeError:
            # 如果報錯就換下一個編碼試試看
            continue
        except KeyError:
            # 如果出現 KeyError 代表欄位讀成亂碼了，也跳過換下一個
            continue
        except Exception as e:
            print(f"❌ 發生錯誤：{e}")
            return
    else:
        print("❌ 所有的編碼都試過了，還是無法讀取，請確認檔案是否損壞。")
        return

    try:
        # 輸出成 JSON 檔案 (統一存成最通用的 utf-8)
        with open(json_filename, mode='w', encoding='utf-8') as json_file:
            json.dump(fare_data, json_file, ensure_ascii=False, indent=2)
            
        print("🎉 轉換成功！")
        print(f"總共處理了 {len(fare_data)} 個起站的資料。")
        print(f"檔案已儲存為：{json_filename}")

    except Exception as e:
        print(f"❌ 發生錯誤：{e}")

# 執行轉換
convert_mrt_fare_csv_to_json('臺北捷運系統票價資料(1141016).csv', 'TPEMRT_Fare.json')