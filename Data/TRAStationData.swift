import Foundation

struct TRAStation: Identifiable, Hashable {
    let id: String
    let name: String  // 中文站名
}

struct TRARegion: Identifiable, Hashable {
    let id: String
    let name: String  // 中文區域名
    let stations: [TRAStation]
}

class TRAStationData {
    static let shared = TRAStationData()

    // 全台車站清單（备用查询用）
    let allStations: [TRAStation] = [
        TRAStation(id: "0900", name: "基隆"),
        TRAStation(id: "0910", name: "三坑"),
        TRAStation(id: "0920", name: "八堵"),
        TRAStation(id: "0930", name: "七堵"),
        TRAStation(id: "0940", name: "百福"),
        TRAStation(id: "0950", name: "五堵"),
        TRAStation(id: "0960", name: "汐止"),
        TRAStation(id: "0970", name: "汐科"),
        TRAStation(id: "0980", name: "南港"),
        TRAStation(id: "0990", name: "松山"),
        TRAStation(id: "1000", name: "臺北"),
        TRAStation(id: "1001", name: "臺北-環島"),
        TRAStation(id: "1010", name: "萬華"),
        TRAStation(id: "1020", name: "板橋"),
        TRAStation(id: "1030", name: "浮洲"),
        TRAStation(id: "1040", name: "樹林"),
        TRAStation(id: "1050", name: "南樹林"),
        TRAStation(id: "1060", name: "山佳"),
        TRAStation(id: "1070", name: "鶯歌"),
        TRAStation(id: "1075", name: "鳳鳴"),
        TRAStation(id: "1080", name: "桃園"),
        TRAStation(id: "1090", name: "內壢"),
        TRAStation(id: "1100", name: "中壢"),
        TRAStation(id: "1110", name: "埔心"),
        TRAStation(id: "1120", name: "楊梅"),
        TRAStation(id: "1130", name: "富岡"),
        TRAStation(id: "1140", name: "新富"),
        TRAStation(id: "7290", name: "福隆"),
        TRAStation(id: "7300", name: "貢寮"),
        TRAStation(id: "7310", name: "雙溪"),
        TRAStation(id: "7320", name: "牡丹"),
        TRAStation(id: "7330", name: "三貂嶺"),
        TRAStation(id: "7331", name: "大華"),
        TRAStation(id: "7332", name: "十分"),
        TRAStation(id: "7333", name: "望古"),
        TRAStation(id: "7334", name: "嶺腳"),
        TRAStation(id: "7335", name: "平溪"),
        TRAStation(id: "7336", name: "菁桐"),
        TRAStation(id: "7350", name: "猴硐"),
        TRAStation(id: "7360", name: "瑞芳"),
        TRAStation(id: "7361", name: "海科館"),
        TRAStation(id: "7362", name: "八斗子"),
        TRAStation(id: "7380", name: "四腳亭"),
        TRAStation(id: "7390", name: "暖暖"),
    ]
    
    // 基北北桃方案：按區域分類（兩層）
    lazy var regions: [TRARegion] = [
        // 區域 1: 縱貫北段基隆（0900~0940）
        TRARegion(
            id: "region_keelung",
            name: "縱貫北段基隆",
            stations: [
                TRAStation(id: "0900", name: "基隆"),
                TRAStation(id: "0910", name: "三坑"),
                TRAStation(id: "0920", name: "八堵"),
                TRAStation(id: "0930", name: "七堵"),
                TRAStation(id: "0940", name: "百福"),
            ]
        ),
        // 區域 2: 縱貫北段台北（0980~1010）
        TRARegion(
            id: "region_taipei",
            name: "縱貫北段台北",
            stations: [
                TRAStation(id: "0980", name: "南港"),
                TRAStation(id: "0990", name: "松山"),
                TRAStation(id: "1000", name: "臺北"),
                TRAStation(id: "1010", name: "萬華"),
            ]
        ),
        // 區域 3: 縱貫北段新北（1020~1075）
        TRARegion(
            id: "region_newtp",
            name: "縱貫北段新北",
            stations: [
                TRAStation(id: "0950", name: "五堵"),
                TRAStation(id: "0960", name: "汐止"),
                TRAStation(id: "0970", name: "汐科"),
                TRAStation(id: "1020", name: "板橋"),
                TRAStation(id: "1030", name: "浮洲"),
                TRAStation(id: "1040", name: "樹林"),
                TRAStation(id: "1050", name: "南樹林"),
                TRAStation(id: "1060", name: "山佳"),
                TRAStation(id: "1070", name: "鶯歌"),
                TRAStation(id: "1075", name: "鳳鳴"),
            ]
        ),
        // 區域 4: 縱貫北段桃園（1080~1140）
        TRARegion(
            id: "region_taoyuan",
            name: "縱貫北段桃園",
            stations: [
                TRAStation(id: "1080", name: "桃園"),
                TRAStation(id: "1090", name: "內壢"),
                TRAStation(id: "1100", name: "中壢"),
                TRAStation(id: "1110", name: "埔心"),
                TRAStation(id: "1120", name: "楊梅"),
                TRAStation(id: "1130", name: "富岡"),
                TRAStation(id: "1140", name: "新富"),
            ]
        ),
        // 區域 5: 平溪/深澳線（7331~7362）
        TRARegion(
            id: "region_pingxi",
            name: "平溪/深澳線",
            stations: [
                TRAStation(id: "7331", name: "大華"),
                TRAStation(id: "7332", name: "十分"),
                TRAStation(id: "7333", name: "望古"),
                TRAStation(id: "7334", name: "嶺腳"),
                TRAStation(id: "7335", name: "平溪"),
                TRAStation(id: "7336", name: "菁桐"),
                TRAStation(id: "7350", name: "猴硐"),
                TRAStation(id: "7360", name: "瑞芳"),
                TRAStation(id: "7361", name: "海科館"),
                TRAStation(id: "7362", name: "八斗子"),
            ]
        ),
        // 區域 6: 宜蘭線（7290~7330、7380、7390）
        TRARegion(
            id: "region_yilan",
            name: "宜蘭線",
            stations: [
                TRAStation(id: "7390", name: "暖暖"),
                TRAStation(id: "7380", name: "四腳亭"),
                TRAStation(id: "7350", name: "猴硐"),
                TRAStation(id: "7360", name: "瑞芳"),
                TRAStation(id: "7330", name: "三貂嶺"),
                TRAStation(id: "7320", name: "牡丹"),
                TRAStation(id: "7310", name: "雙溪"),
                TRAStation(id: "7300", name: "貢寮"),
                TRAStation(id: "7290", name: "福隆"),
            ]
        ),
    ]

    func getStationName(id: String) -> String {
        return allStations.first { $0.id == id }?.name ?? id
    }
    
    // 雙語化支援：中文站名 → 英文站名
    private let stationNameENByZH: [String: String] = [
        // 縱貫北段基隆
        "基隆": "Keelung",
        "三坑": "Sankeng",
        "八堵": "Badu",
        "七堵": "Qidu",
        "百福": "Baifu",
        // 縱貫北段台北
        "南港": "Nangang",
        "松山": "Songshan",
        "臺北": "Taipei",
        "萬華": "Wanhua",
        // 縱貫北段新北
        "五堵": "Wudu",
        "汐止": "Xizhi",
        "汐科": "Xike",
        "板橋": "Banqiao",
        "浮洲": "Fuzhou",
        "樹林": "Shulin",
        "南樹林": "S. Shulin",
        "山佳": "Shanjia",
        "鶯歌": "Yingge",
        "鳳鳴": "Fengming",
        // 縱貫北段桃園
        "桃園": "Taoyuan",
        "內壢": "Neili",
        "中壢": "Zhongli",
        "埔心": "Puxin",
        "楊梅": "Yangmei",
        "富岡": "Fugang",
        "新富": "Xinfu",
        // 平溪線
        "福隆": "Fulong",
        "貢寮": "Gongliao",
        "雙溪": "Shuangxi",
        "牡丹": "Mudan",
        "三貂嶺": "Sandiaoling",
        "大華": "Dahua",
        "十分": "Shifen",
        "望古": "Wanggu",
        "嶺腳": "Lingjiao",
        "平溪": "Pingxi",
        "菁桐": "Jingtong",
        // 宜蘭線
        "猴硐": "Houtong",
        "瑞芳": "Ruifang",
        "海科館": "Marine Science Museum",
        "八斗子": "Badouzi",
        "四腳亭": "Sijiaoting",
        "暖暖": "Nuannuan",
    ]
    
    // 區域名稱雙語化
    private let regionNameENByZH: [String: String] = [
        "縱貫北段基隆": "Main Line Keelung",
        "縱貫北段台北": "Main Line Taipei",
        "縱貫北段新北": "Main Line New Taipei",
        "縱貫北段桃園": "Main Line Taoyuan",
        "平溪/深澳線": "Pingxi/Shennao Line",
        "宜蘭線": "Yilan Line",
    ]
    
    // 建立反向查表：英文 → 中文（用於輸入轉換）
    lazy var stationNameZHByEN: [String: String] = {
        var result: [String: String] = [:]
        for (zh, en) in self.stationNameENByZH {
            result[self.normalizedLookupKey(en)] = zh
        }
        return result
    }()
    
    private func normalizedLookupKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    /// 顯示站名（支援多語言）
    /// 顯示站名（支援多語言）- 接收代號或中文名稱
    func displayStationName(_ stationName: String, languageCode: String? = nil) -> String {
        let lang = languageCode ?? (Locale.current.identifier)
        
        // 先檢查是否為代號，若是則先查詢中文名稱
        let zhName = allStations.first { $0.id == stationName }?.name ?? stationName
        
        // 如果不是英文，直接回傳中文名稱
        guard lang.hasPrefix("en") else { return zhName }
        
        // 英文模式：查詢英文翻譯
        return stationNameENByZH[zhName] ?? zhName
    }
    
    /// 顯示區域名稱（支援多語言）
    func displayRegionName(_ regionName: String, languageCode: String? = nil) -> String {
        let lang = languageCode ?? (Locale.current.identifier)
        guard lang.hasPrefix("en") else { return regionName }
        return regionNameENByZH[regionName] ?? regionName
    }
    
    /// 將使用者輸入的站名（可能是英文）轉成中文標準名稱
    func normalizeStationNameToZH(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }
        if stationNameENByZH.keys.contains(trimmed) { return trimmed }
        let normalized = normalizedLookupKey(trimmed)
        return stationNameZHByEN[normalized] ?? trimmed
    }
}

/*
後續全台車站列表（基北北桃方案外的站點，暫時用不到）
        TRAStation(id: "0910", name: "三坑"),
        TRAStation(id: "0920", name: "八堵"),
        TRAStation(id: "0930", name: "七堵"),
        TRAStation(id: "0940", name: "百福"),
        TRAStation(id: "0950", name: "五堵"),
        TRAStation(id: "0960", name: "汐止"),
        TRAStation(id: "0970", name: "汐科"),
        TRAStation(id: "0980", name: "南港"),
        TRAStation(id: "0990", name: "松山"),
        TRAStation(id: "1000", name: "臺北"),
        TRAStation(id: "1001", name: "臺北-環島"),
        TRAStation(id: "1010", name: "萬華"),
        TRAStation(id: "1020", name: "板橋"),
        TRAStation(id: "1030", name: "浮洲"),
        TRAStation(id: "1040", name: "樹林"),
        TRAStation(id: "1050", name: "南樹林"),
        TRAStation(id: "1060", name: "山佳"),
        TRAStation(id: "1070", name: "鶯歌"),
        TRAStation(id: "1075", name: "鳳鳴"),
        TRAStation(id: "1080", name: "桃園"),
        TRAStation(id: "1090", name: "內壢"),
        TRAStation(id: "1100", name: "中壢"),
        TRAStation(id: "1110", name: "埔心"),
        TRAStation(id: "1120", name: "楊梅"),
        TRAStation(id: "1130", name: "富岡"),
        TRAStation(id: "1140", name: "新富"),
        TRAStation(id: "1150", name: "北湖"),
        TRAStation(id: "1160", name: "湖口"),
        TRAStation(id: "1170", name: "新豐"),
        TRAStation(id: "1180", name: "竹北"),
        TRAStation(id: "1190", name: "北新竹"),
        TRAStation(id: "1191", name: "千甲"),
        TRAStation(id: "1192", name: "新莊"),
        TRAStation(id: "1193", name: "竹中"),
        TRAStation(id: "1194", name: "六家"),
        TRAStation(id: "1201", name: "上員"),
        TRAStation(id: "1202", name: "榮華"),
        TRAStation(id: "1203", name: "竹東"),
        TRAStation(id: "1204", name: "橫山"),
        TRAStation(id: "1205", name: "九讚頭"),
        TRAStation(id: "1206", name: "合興"),
        TRAStation(id: "1207", name: "富貴"),
        TRAStation(id: "1208", name: "內灣"),
        TRAStation(id: "1210", name: "新竹"),
        TRAStation(id: "1220", name: "三姓橋"),
        TRAStation(id: "1230", name: "香山"),
        TRAStation(id: "1240", name: "崎頂"),
        TRAStation(id: "1250", name: "竹南"),
        TRAStation(id: "2110", name: "談文"),
        TRAStation(id: "2120", name: "大山"),
        TRAStation(id: "2130", name: "後龍"),
        TRAStation(id: "2140", name: "龍港"),
        TRAStation(id: "2150", name: "白沙屯"),
        TRAStation(id: "2160", name: "新埔"),
        TRAStation(id: "2170", name: "通霄"),
        TRAStation(id: "2180", name: "苑裡"),
        TRAStation(id: "2190", name: "日南"),
        TRAStation(id: "2200", name: "大甲"),
        TRAStation(id: "2210", name: "臺中港"),
        TRAStation(id: "2220", name: "清水"),
        TRAStation(id: "2230", name: "沙鹿"),
        TRAStation(id: "2240", name: "龍井"),
        TRAStation(id: "2250", name: "大肚"),
        TRAStation(id: "2260", name: "追分"),
        TRAStation(id: "3140", name: "造橋"),
        TRAStation(id: "3150", name: "豐富"),
        TRAStation(id: "3160", name: "苗栗"),
        TRAStation(id: "3170", name: "南勢"),
        TRAStation(id: "3180", name: "銅鑼"),
        TRAStation(id: "3190", name: "三義"),
        TRAStation(id: "3210", name: "泰安"),
        TRAStation(id: "3220", name: "后里"),
        TRAStation(id: "3230", name: "豐原"),
        TRAStation(id: "3240", name: "栗林"),
        TRAStation(id: "3250", name: "潭子"),
        TRAStation(id: "3260", name: "頭家厝"),
        TRAStation(id: "3270", name: "松竹"),
        TRAStation(id: "3280", name: "太原"),
        TRAStation(id: "3290", name: "精武"),
        TRAStation(id: "3300", name: "臺中"),
        TRAStation(id: "3310", name: "五權"),
        TRAStation(id: "3320", name: "大慶"),
        TRAStation(id: "3330", name: "烏日"),
        TRAStation(id: "3340", name: "新烏日"),
        TRAStation(id: "3350", name: "成功"),
        TRAStation(id: "3360", name: "彰化"),
        TRAStation(id: "3370", name: "花壇"),
        TRAStation(id: "3380", name: "大村"),
        TRAStation(id: "3390", name: "員林"),
        TRAStation(id: "3400", name: "永靖"),
        TRAStation(id: "3410", name: "社頭"),
        TRAStation(id: "3420", name: "田中"),
        TRAStation(id: "3430", name: "二水"),
        TRAStation(id: "3431", name: "源泉"),
        TRAStation(id: "3432", name: "濁水"),
        TRAStation(id: "3433", name: "龍泉"),
        TRAStation(id: "3434", name: "集集"),
        TRAStation(id: "3435", name: "水里"),
        TRAStation(id: "3436", name: "車埕"),
        TRAStation(id: "3450", name: "林內"),
        TRAStation(id: "3460", name: "石榴"),
        TRAStation(id: "3470", name: "斗六"),
        TRAStation(id: "3480", name: "斗南"),
        TRAStation(id: "3490", name: "石龜"),
        TRAStation(id: "4050", name: "大林"),
        TRAStation(id: "4060", name: "民雄"),
        TRAStation(id: "4070", name: "嘉北"),
        TRAStation(id: "4080", name: "嘉義"),
        TRAStation(id: "4090", name: "水上"),
        TRAStation(id: "4100", name: "南靖"),
        TRAStation(id: "4110", name: "後壁"),
        TRAStation(id: "4120", name: "新營"),
        TRAStation(id: "4130", name: "柳營"),
        TRAStation(id: "4140", name: "林鳳營"),
        TRAStation(id: "4150", name: "隆田"),
        TRAStation(id: "4160", name: "拔林"),
        TRAStation(id: "4170", name: "善化"),
        TRAStation(id: "4180", name: "南科"),
        TRAStation(id: "4190", name: "新市"),
        TRAStation(id: "4200", name: "永康"),
        TRAStation(id: "4210", name: "大橋"),
        TRAStation(id: "4220", name: "臺南"),
        TRAStation(id: "4250", name: "保安"),
        TRAStation(id: "4260", name: "仁德"),
        TRAStation(id: "4270", name: "中洲"),
        TRAStation(id: "4271", name: "長榮大學"),
        TRAStation(id: "4272", name: "沙崙"),
        TRAStation(id: "4290", name: "大湖"),
        TRAStation(id: "4300", name: "路竹"),
        TRAStation(id: "4310", name: "岡山"),
        TRAStation(id: "4320", name: "橋頭"),
        TRAStation(id: "4330", name: "楠梓"),
        TRAStation(id: "4340", name: "新左營"),
        TRAStation(id: "4350", name: "左營"),
        TRAStation(id: "4360", name: "內惟"),
        TRAStation(id: "4370", name: "美術館"),
        TRAStation(id: "4380", name: "鼓山"),
        TRAStation(id: "4390", name: "三塊厝"),
        TRAStation(id: "4400", name: "高雄"),
        TRAStation(id: "4410", name: "民族"),
        TRAStation(id: "4420", name: "科工館"),
        TRAStation(id: "4430", name: "正義"),
        TRAStation(id: "4440", name: "鳳山"),
        TRAStation(id: "4450", name: "後庄"),
        TRAStation(id: "4460", name: "九曲堂"),
        TRAStation(id: "4470", name: "六塊厝"),
        TRAStation(id: "5000", name: "屏東"),
        TRAStation(id: "5010", name: "歸來"),
        TRAStation(id: "5020", name: "麟洛"),
        TRAStation(id: "5030", name: "西勢"),
        TRAStation(id: "5040", name: "竹田"),
        TRAStation(id: "5050", name: "潮州"),
        TRAStation(id: "5060", name: "崁頂"),
        TRAStation(id: "5070", name: "南州"),
        TRAStation(id: "5080", name: "鎮安"),
        TRAStation(id: "5090", name: "林邊"),
        TRAStation(id: "5100", name: "佳冬"),
        TRAStation(id: "5110", name: "東海"),
        TRAStation(id: "5120", name: "枋寮"),
        TRAStation(id: "5130", name: "加祿"),
        TRAStation(id: "5140", name: "內獅"),
        TRAStation(id: "5160", name: "枋山"),
        TRAStation(id: "5170", name: "枋野"),
        TRAStation(id: "5190", name: "大武"),
        TRAStation(id: "5200", name: "瀧溪"),
        TRAStation(id: "5210", name: "金崙"),
        TRAStation(id: "5220", name: "太麻里"),
        TRAStation(id: "5230", name: "知本"),
        TRAStation(id: "5240", name: "康樂"),
        TRAStation(id: "5998", name: "南方小站"),
        TRAStation(id: "5999", name: "潮州基地"),
        TRAStation(id: "6000", name: "臺東"),
        TRAStation(id: "6010", name: "山里"),
        TRAStation(id: "6020", name: "鹿野"),
        TRAStation(id: "6030", name: "瑞源"),
        TRAStation(id: "6040", name: "瑞和"),
        TRAStation(id: "6050", name: "關山"),
        TRAStation(id: "6060", name: "海端"),
        TRAStation(id: "6070", name: "池上"),
        TRAStation(id: "6080", name: "富里"),
        TRAStation(id: "6090", name: "東竹"),
        TRAStation(id: "6100", name: "東里"),
        TRAStation(id: "6110", name: "玉里"),
        TRAStation(id: "6120", name: "三民"),
        TRAStation(id: "6130", name: "瑞穗"),
        TRAStation(id: "6140", name: "富源"),
        TRAStation(id: "6150", name: "大富"),
        TRAStation(id: "6160", name: "光復"),
        TRAStation(id: "6170", name: "萬榮"),
        TRAStation(id: "6180", name: "鳳林"),
        TRAStation(id: "6190", name: "南平"),
        TRAStation(id: "6200", name: "林榮新光"),
        TRAStation(id: "6210", name: "豐田"),
        TRAStation(id: "6220", name: "壽豐"),
        TRAStation(id: "6230", name: "平和"),
        TRAStation(id: "6240", name: "志學"),
        TRAStation(id: "6250", name: "吉安"),
        TRAStation(id: "7000", name: "花蓮"),
        TRAStation(id: "7010", name: "北埔"),
        TRAStation(id: "7020", name: "景美"),
        TRAStation(id: "7030", name: "新城"),
        TRAStation(id: "7040", name: "崇德"),
        TRAStation(id: "7050", name: "和仁"),
        TRAStation(id: "7060", name: "和平"),
        TRAStation(id: "7070", name: "漢本"),
        TRAStation(id: "7080", name: "武塔"),
        TRAStation(id: "7090", name: "南澳"),
        TRAStation(id: "7100", name: "東澳"),
        TRAStation(id: "7110", name: "永樂"),
        TRAStation(id: "7120", name: "蘇澳"),
        TRAStation(id: "7130", name: "蘇澳新"),
        TRAStation(id: "7140", name: "新馬"),
        TRAStation(id: "7150", name: "冬山"),
        TRAStation(id: "7160", name: "羅東"),
        TRAStation(id: "7170", name: "中里"),
        TRAStation(id: "7180", name: "二結"),
        TRAStation(id: "7190", name: "宜蘭"),
        TRAStation(id: "7200", name: "四城"),
        TRAStation(id: "7210", name: "礁溪"),
        TRAStation(id: "7220", name: "頂埔"),
        TRAStation(id: "7230", name: "頭城"),
        TRAStation(id: "7240", name: "外澳"),
        TRAStation(id: "7250", name: "龜山"),
        TRAStation(id: "7260", name: "大溪"),
        TRAStation(id: "7270", name: "大里"),
        TRAStation(id: "7280", name: "石城"),
        TRAStation(id: "7290", name: "福隆"),
        TRAStation(id: "7300", name: "貢寮"),
        TRAStation(id: "7310", name: "雙溪"),
        TRAStation(id: "7320", name: "牡丹"),
        TRAStation(id: "7330", name: "三貂嶺"),
        TRAStation(id: "7331", name: "大華"),
        TRAStation(id: "7332", name: "十分"),
        TRAStation(id: "7333", name: "望古"),
        TRAStation(id: "7334", name: "嶺腳"),
        TRAStation(id: "7335", name: "平溪"),
        TRAStation(id: "7336", name: "菁桐"),
        TRAStation(id: "7350", name: "猴硐"),
        TRAStation(id: "7360", name: "瑞芳"),
        TRAStation(id: "7361", name: "海科館"),
        TRAStation(id: "7362", name: "八斗子"),
        TRAStation(id: "7380", name: "四腳亭"),
        TRAStation(id: "7390", name: "暖暖"),
    ]
*/
