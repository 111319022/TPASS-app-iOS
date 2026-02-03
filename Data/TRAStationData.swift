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
    
    // 全台車站清單（完整版）
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
    
    // MARK: - 物理區域定義 (改為明確列出站名)
    // 這樣可以靈活處理支線共用站點 (例如瑞芳、二水、新竹)
    private var rawRegions: [TRARegion] {
        return [
            createRegion(id: "R1", name: "縱貫線北段 (基隆-竹南)", stationNames: [
                "基隆", "三坑", "八堵", "七堵", "百福", "五堵", "汐止", "汐科", "南港", "松山", "臺北", "萬華", "板橋", "浮洲", "樹林", "南樹林", "山佳", "鶯歌", "鳳鳴", "桃園", "內壢", "中壢", "埔心", "楊梅", "富岡", "新富", "北湖", "湖口", "新豐", "竹北", "北新竹", "新竹", "三姓橋", "香山", "崎頂", "竹南"
            ]),
            
            createRegion(id: "R2", name: "山線 (造橋-成功)", stationNames: [
                "造橋", "豐富", "苗栗", "南勢", "銅鑼", "三義", "泰安", "后里", "豐原", "栗林", "潭子", "頭家厝", "松竹", "太原", "精武", "臺中", "五權", "大慶", "烏日", "新烏日", "成功"
            ]),
            
            createRegion(id: "R3", name: "海線 (談文-追分)", stationNames: [
                "談文", "大山", "後龍", "龍港", "白沙屯", "新埔", "通霄", "苑裡", "日南", "大甲", "臺中港", "清水", "沙鹿", "龍井", "大肚", "追分"
            ]),
            
            createRegion(id: "R4", name: "縱貫線南段 (彰化-高雄)", stationNames: [
                "彰化", "花壇", "大村", "員林", "永靖", "社頭", "田中", "二水", "林內", "石榴", "斗六", "斗南", "石龜", "大林", "民雄", "嘉北", "嘉義", "水上", "南靖", "後壁", "新營", "柳營", "林鳳營", "隆田", "拔林", "善化", "南科", "新市", "永康", "大橋", "臺南", "保安", "仁德", "中洲", "大湖", "路竹", "岡山", "橋頭", "楠梓", "新左營", "左營", "內惟", "美術館", "鼓山", "三塊厝", "高雄"
            ]),
            
            createRegion(id: "R5", name: "屏東/南迴線", stationNames: [
                "高雄", "民族", "科工館", "正義", "鳳山", "後庄", "九曲堂", "六塊厝", "屏東", "歸來", "麟洛", "西勢", "竹田", "潮州", "崁頂", "南州", "鎮安", "林邊", "佳冬", "東海", "枋寮", "加祿", "內獅", "枋山"
            ]),
            
            createRegion(id: "R6", name: "宜蘭線 (八堵-蘇澳)", stationNames: [
                "八堵", "暖暖", "四腳亭", "瑞芳", "猴硐", "三貂嶺", "牡丹", "雙溪", "貢寮", "福隆", "石城", "大里", "大溪", "龜山", "外澳", "頭城", "頂埔", "礁溪", "四城", "宜蘭", "二結", "中里", "羅東", "冬山", "新馬", "蘇澳新", "蘇澳"
            ]),
            
            createRegion(id: "R7", name: "平溪/深澳線", stationNames: [
                "海科館", "八斗子", "瑞芳",  "猴硐", "三貂嶺", "大華", "十分", "望古", "嶺腳", "平溪", "菁桐"
            ]),
            
            createRegion(id: "R8", name: "內灣/六家線", stationNames: [
                "新竹", "北新竹", "千甲", "新莊", "竹中", "六家", "上員", "榮華", "竹東", "橫山", "九讚頭", "合興", "富貴", "內灣"
            ]),
            
            createRegion(id: "R9", name: "集集線", stationNames: [
                "二水", "源泉", "濁水", "龍泉", "集集", "水里", "車埕"
            ]),
            
            createRegion(id: "R10", name: "沙崙線", stationNames: [
                "中洲", "長榮大學", "沙崙"
            ])
        ]
    }
    
    /// 根據站名列表建立區域 (解決排序與重複問題)
    private func createRegion(id: String, name: String, stationNames: [String]) -> TRARegion {
        // 從 allStations 中找出對應名稱的車站物件，並保持傳入陣列的順序
        var stations: [TRAStation] = []
        for name in stationNames {
            if let station = allStations.first(where: { $0.name == name }) {
                stations.append(station)
            }
        }
        return TRARegion(id: id, name: name, stations: stations)
    }
    
    // MARK: - 核心邏輯：根據 TPASS 方案過濾區域與車站
    
    /// 回傳該方案可用的「區域列表」，每個區域內只包含該方案允許的「車站」
    func getRegions(for plan: TPASSRegion) -> [TRARegion] {
        let validRanges = plan.traStationIDRange() // [(String, String)]
        
        // 1. 收集該方案所有合法的車站 ID
        var validStationIDs = Set<String>()
        for (startID, endID) in validRanges {
            let stationsInRange = allStations.filter { $0.id >= startID && $0.id <= endID }
            stationsInRange.forEach { validStationIDs.insert($0.id) }
        }
        
        // 2. 遍歷物理區域，過濾出內容
        var filteredRegions: [TRARegion] = []
        
        for region in rawRegions {
            // 這個區域內有哪些車站是該方案允許的？
            let validStations = region.stations.filter { validStationIDs.contains($0.id) }
            
            // 如果這個區域有任何合法車站，就加入列表
            if !validStations.isEmpty {
                filteredRegions.append(TRARegion(id: region.id, name: region.name, stations: validStations))
            }
        }
        
        return filteredRegions
    }
    
    /// 為了相容性：將 getRegions 的結果攤平成車站列表
    func getStations(for region: TPASSRegion) -> [TRAStation] {
        return getRegions(for: region).flatMap { $0.stations }
    }
    
    // 雙語化支援：中文站名 → 英文站名 (依照 ID 0900-7390 排序)
    private let stationNameENByZH: [String: String] = [
        // 0900 - 0990
        "基隆": "Keelung",
        "三坑": "Sankeng",
        "八堵": "Badu",
        "七堵": "Qidu",
        "百福": "Baifu",
        "五堵": "Wudu",
        "汐止": "Xizhi",
        "汐科": "Xike",
        "南港": "Nangang",
        "松山": "Songshan",
        
        // 1000 - 1075
        "臺北": "Taipei",
        "臺北-環島": "Taipei",
        "萬華": "Wanhua",
        "板橋": "Banqiao",
        "浮洲": "Fuzhou",
        "樹林": "Shulin",
        "南樹林": "S. Shulin",
        "山佳": "Shanjia",
        "鶯歌": "Yingge",
        "鳳鳴": "Fengming",
        
        // 1080 - 1180
        "桃園": "Taoyuan",
        "內壢": "Neili",
        "中壢": "Zhongli",
        "埔心": "Puxin",
        "楊梅": "Yangmei",
        "富岡": "Fugang",
        "新富": "Xinfu",
        "北湖": "Beihu",
        "湖口": "Hukou",
        "新豐": "Xinfeng",
        "竹北": "Zhubei",
        
        // 1190 - 1250 (包含內灣/六家線)
        "北新竹": "North Hsinchu",
        "千甲": "Qianjia",
        "新莊": "Xinzhuang",
        "竹中": "Zhuzhong",
        "六家": "Liujia",
        "上員": "Shangyuan",
        "榮華": "Ronghua",
        "竹東": "Zhudong",
        "橫山": "Hengshan",
        "九讚頭": "Jiuzantou",
        "合興": "Hexing",
        "富貴": "Fugui",
        "內灣": "Neiwan",
        "新竹": "Hsinchu",
        "三姓橋": "Sanxingqiao",
        "香山": "Xiangshan",
        "崎頂": "Qiding",
        "竹南": "Zhunan",
        
        // 2110 - 2260 (海線)
        "談文": "Tanwen",
        "大山": "Dashan",
        "後龍": "Houlong",
        "龍港": "Longgang",
        "白沙屯": "Baishatun",
        "新埔": "Xinpu",
        "通霄": "Tongxiao",
        "苑裡": "Yuanli",
        "日南": "Rinan",
        "大甲": "Dajia",
        "臺中港": "Taichung Port",
        "清水": "Qingshui",
        "沙鹿": "Shalu",
        "龍井": "Longjing",
        "大肚": "Dadu",
        "追分": "Zhuifen",
        
        // 3140 - 3350 (山線)
        "造橋": "Zaoqiao",
        "豐富": "Fengfu",
        "苗栗": "Miaoli",
        "南勢": "Nanshi",
        "銅鑼": "Tongluo",
        "三義": "Sanyi",
        "泰安": "Taian",
        "后里": "Houli",
        "豐原": "Fengyuan",
        "栗林": "Lilin",
        "潭子": "Tanzi",
        "頭家厝": "Toujiacuo",
        "松竹": "Songzhu",
        "太原": "Taiyuan",
        "精武": "Jingwu",
        "臺中": "Taichung",
        "五權": "Wuquan",
        "大慶": "Daqing",
        "烏日": "Wuri",
        "新烏日": "Xinwuri",
        "成功": "Chenggong",
        
        // 3360 - 3436 (彰化-二水 & 集集線)
        "彰化": "Changhua",
        "花壇": "Huatan",
        "大村": "Dacun",
        "員林": "Yuanlin",
        "永靖": "Yongjing",
        "社頭": "Shetou",
        "田中": "Tianzhong",
        "二水": "Ershui",
        "源泉": "Yuanquan",
        "濁水": "Zhuoshui",
        "龍泉": "Longquan",
        "集集": "Jiji",
        "水里": "Shuili",
        "車埕": "Checheng",
        
        // 3450 - 4200 (斗六-台南)
        "林內": "Linnei",
        "石榴": "Shiliu",
        "斗六": "Douliu",
        "斗南": "Dounan",
        "石龜": "Shigui",
        "大林": "Dalin",
        "民雄": "Minxiong",
        "嘉北": "Jiabei",
        "嘉義": "Chiayi",
        "水上": "Shuishang",
        "南靖": "Nanjing",
        "後壁": "Houbi",
        "新營": "Xinying",
        "柳營": "Liuying",
        "林鳳營": "Linfengying",
        "隆田": "Longtian",
        "拔林": "Balin",
        "善化": "Shanhua",
        "南科": "Nanke",
        "新市": "Xinshi",
        "永康": "Yongkang",
        
        // 4210 - 4272 (台南-沙崙)
        "大橋": "Daqiao",
        "臺南": "Tainan",
        "保安": "Baoan",
        "仁德": "Rende",
        "中洲": "Zhongzhou",
        "長榮大學": "Chang Jung Christian University",
        "沙崙": "Shalun",
        
        // 4290 - 4470 (高雄區段)
        "大湖": "Dahu",
        "路竹": "Luzhu",
        "岡山": "Gangshan",
        "橋頭": "Qiaotou",
        "楠梓": "Nanzi",
        "新左營": "Xinzuoying",
        "左營": "Zuoying",
        "內惟": "Neiwei",
        "美術館": "Museum of Fine Arts",
        "鼓山": "Gushan",
        "三塊厝": "Sankuaicuo",
        "高雄": "Kaohsiung",
        "民族": "Minzu",
        "科工館": "Science and Technology Museum",
        "正義": "Zhengyi",
        "鳳山": "Fengshan",
        "後庄": "Houzhuang",
        "九曲堂": "Jiuqutang",
        "六塊厝": "Liukuaicuo",
        
        // 5000 - 5240 (屏東/南迴)
        "屏東": "Pingtung",
        "歸來": "Guilai",
        "麟洛": "Linluo",
        "西勢": "Xishi",
        "竹田": "Zhutian",
        "潮州": "Chaozhou",
        "崁頂": "Kanding",
        "南州": "Nanzhou",
        "鎮安": "Zhenan",
        "林邊": "Linbian",
        "佳冬": "Jiadong",
        "東海": "Donghai",
        "枋寮": "Fangliao",
        "加祿": "Jialu",
        "內獅": "Neishi",
        "枋山": "Fangshan",
        "枋野": "Fangye",
        "大武": "Dawu",
        "瀧溪": "Longxi",
        "金崙": "Jinlun",
        "太麻里": "Taimali",
        "知本": "Zhiben",
        "康樂": "Kangle",
        
        // 5998 - 6250 (台東-花蓮)
        "南方小站": "Nanfang Xiaozhan",
        "潮州基地": "Chaozhou Base",
        "臺東": "Taitung",
        "山里": "Shanli",
        "鹿野": "Luye",
        "瑞源": "Ruiyuan",
        "瑞和": "Ruihe",
        "關山": "Guanshan",
        "海端": "Haiduan",
        "池上": "Chishang",
        "富里": "Fuli",
        "東竹": "Dongzhu",
        "東里": "Dongli",
        "玉里": "Yuli",
        "三民": "Sanmin",
        "瑞穗": "Ruisui",
        "富源": "Fuyuan",
        "大富": "Dafu",
        "光復": "Guangfu",
        "萬榮": "Wanrong",
        "鳳林": "Fenglin",
        "南平": "Nanping",
        "林榮新光": "Linrong Shin Kong",
        "豐田": "Fengtian",
        "壽豐": "Shoufeng",
        "平和": "Pinghe",
        "志學": "Zhixue",
        "吉安": "Jian",
        
        // 7000 - 7390 (花蓮-暖暖，含宜蘭/平溪線)
        "花蓮": "Hualien",
        "北埔": "Beipu",
        "景美": "Jingmei",
        "新城": "Xincheng",
        "崇德": "Chongde",
        "和仁": "Heren",
        "和平": "Heping",
        "漢本": "Hanben",
        "武塔": "Wuta",
        "南澳": "Nanao",
        "東澳": "Dongao",
        "永樂": "Yongle",
        "蘇澳": "Suao",
        "蘇澳新": "Suao New",
        "新馬": "Xinma",
        "冬山": "Dongshan",
        "羅東": "Luodong",
        "中里": "Zhongli",
        "二結": "Erjie",
        "宜蘭": "Yilan",
        "四城": "Sicheng",
        "礁溪": "Jiaoxi",
        "頂埔": "Dingpu",
        "頭城": "Toucheng",
        "外澳": "Waiao",
        "龜山": "Guishan",
        "大溪": "Daxi",
        "大里": "Dali",
        "石城": "Shicheng",
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
        "猴硐": "Houtong",
        "瑞芳": "Ruifang",
        "海科館": "Marine Science Museum",
        "八斗子": "Badouzi",
        "四腳亭": "Sijiaoting",
        "暖暖": "Nuannuan"
    ]
    
    // 區域名稱雙語化
    private let regionNameENByZH: [String: String] = [
        // 目前 rawRegions 使用的線路名稱（主用）
        "縱貫線北段 (基隆-竹南)": "Main Line N. (Keelung–Zhunan)",
        "山線 (造橋-成功)": "Mt. Line (Zaoqiao–Chenggong)",
        "海線 (談文-追分)": "Coast Line (Tanwen–Zhuifen)",
        "縱貫線南段 (彰化-高雄)": "Main Line S. (Changhua–Kaohsiung)",
        "屏東/南迴線": "Pingtung / S. Link Line",
        "宜蘭線 (八堵-蘇澳)": "Yilan Line (Badu–Su'ao)",
        "平溪/深澳線": "Pingxi / Shen'ao Line",
        "內灣/六家線": "Neiwan / Liujia Line",
        "集集線": "Jiji Line",
        "沙崙線": "Shalun Line",

        // 舊版/相容 key（避免既有資料或 UI 還在用時失效）
        
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
        TRAStation(id: "1140", name: "新富        "),
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
