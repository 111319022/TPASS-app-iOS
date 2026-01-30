import Foundation
import SwiftUI

struct MRTLine: Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let color: Color
    let stations: [String]
}

class StationData {
    static let shared = StationData()
    
    // 對應 Web 版的 MRT_LINES
    let lines: [MRTLine] = [
        MRTLine(id: "BL", code: "BL", name: "🔵板南線", color: Color(hex: "#0070BD"), stations: [
            "頂埔", "永寧", "土城", "海山", "亞東醫院", "府中", "板橋", "新埔", "江子翠", "龍山寺", "西門", "台北車站", "善導寺", "忠孝新生", "忠孝敦化", "國父紀念館", "市政府", "永春", "後山埤", "昆陽", "南港", "南港展覽館"
        ]),
        MRTLine(id: "R", code: "R", name: "🔴淡水信義線", color: Color(hex: "#E3002C"), stations: [
            "象山", "台北101/世貿", "信義安和", "大安", "大安森林公園", "東門", "中正紀念堂", "台大醫院", "台北車站", "中山", "雙連", "民權西路", "圓山", "劍潭", "士林", "芝山", "明德", "石牌", "唭哩岸", "奇岩", "北投", "新北投", "復興崗", "忠義", "關渡", "竹圍", "紅樹林", "淡水"
        ]),
        MRTLine(id: "G", code: "G", name: "🟢松山新店線", color: Color(hex: "#008659"), stations: [
            "新店", "新店區公所", "七張", "小碧潭", "大坪林", "景美", "萬隆", "公館", "台電大樓", "古亭", "中正紀念堂", "小南門", "西門", "北門", "中山", "松江南京", "南京復興", "台北小巨蛋", "南京三民", "松山"
        ]),
        MRTLine(id: "O", code: "O", name: "🟠中和新蘆線", color: Color(hex: "#F8B61C"), stations: [
            "南勢角", "景安", "永安市場", "頂溪", "古亭", "東門", "忠孝新生", "松江南京", "行天宮", "中山國小", "民權西路", "大橋頭", "台北橋", "菜寮", "三重", "先嗇宮", "頭前庄", "新莊", "輔大", "丹鳳", "迴龍", "三重國小", "三和國中", "徐匯中學", "三民高中", "蘆洲"
        ]),
        MRTLine(id: "BR", code: "BR", name: "🟤文湖線", color: Color(hex: "#C48C31"), stations: [
            "動物園", "木柵", "萬芳社區", "萬芳醫院", "辛亥", "麟光", "六張犁", "科技大樓", "大安", "忠孝復興", "南京復興", "中山國中", "松山機場", "大直", "劍南路", "西湖", "港墘", "文德", "內湖", "大湖公園", "葫洲", "東湖", "南港軟體園區", "南港展覽館"
        ]),
        MRTLine(id: "Y", code: "Y", name: "🟡環狀線", color: Color(hex: "#FDBB2D"), stations: [
            "大坪林", "十四張", "秀朗橋", "景平", "景安", "中和", "橋和", "中原", "板新", "板橋", "新埔民生", "頭前庄", "幸福", "新北產業園區"
        ])
    ]
}

extension StationData {
    private static var defaultLanguageCode: String {
        if let stored = UserDefaults.standard.string(forKey: "AppLanguage"), !stored.isEmpty {
            return stored
        }
        return Locale.current.identifier
    }

    private static func normalizedLookupKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static let lineNameENByZH: [String: String] = [
        "🔵板南線": "🔵 Blue line",
        "🔴淡水信義線": "🔴 Red Line",
        "🟢松山新店線": "🟢 Green Line",
        "🟠中和新蘆線": "🟠 Orange Line",
        "🟤文湖線": "🟤 Brown Line",
        "🟡環狀線": "🟡 Circular Line"
    ]

    // 站名採「官方譯名」(常見/官方用法)。資料層仍以中文作為 key。
    private static let stationNameENByZH: [String: String] = [
        // BL (Bannan)
        "頂埔": "Dingpu",
        "永寧": "Yongning",
        "土城": "Tucheng",
        "海山": "Haishan",
        "亞東醫院": "Far Eastern Hospital",
        "府中": "Fuzhong",
        "板橋": "Banqiao",
        "新埔": "Xinpu",
        "江子翠": "Jiangzicui",
        "龍山寺": "Longshan Temple",
        "西門": "Ximen",
        "台北車站": "Taipei Main Station",
        "善導寺": "Shandao Temple",
        "忠孝新生": "Zhongxiao Xinsheng",
        "忠孝敦化": "Zhongxiao Dunhua",
        "國父紀念館": "S.Y.S Memorial Hall",
        "市政府": "Taipei City Hall",
        "永春": "Yongchun",
        "後山埤": "Houshanpi",
        "昆陽": "Kunyang",
        "南港": "Nangang",
        "南港展覽館": "Nangang Exhibit. Center",

        // R (Tamsui-Xinyi)
        "象山": "Xiangshan",
        "台北101/世貿": "Taipei 101/World Trade Center",
        "信義安和": "Xinyi Anhe",
        "大安": "Daan",
        "大安森林公園": "Daan Park",
        "東門": "Dongmen",
        "中正紀念堂": "C.K.S. Memorial Hall",
        "台大醫院": "NTU Hospital",
        "中山": "Zhongshan",
        "雙連": "Shuanglian",
        "民權西路": "Minquan W. Rd.",
        "圓山": "Yuanshan",
        "劍潭": "Jiantan",
        "士林": "Shilin",
        "芝山": "Zhishan",
        "明德": "Mingde",
        "石牌": "Shipai",
        "唭哩岸": "Qilian",
        "奇岩": "Qiyan",
        "北投": "Beitou",
        "新北投": "Xinbeitou",
        "復興崗": "Fuxinggang",
        "忠義": "Zhongyi",
        "關渡": "Guandu",
        "竹圍": "Zhuwei",
        "紅樹林": "Hongshulin",
        "淡水": "Tamsui",

        // G (Songshan-Xindian)
        "新店": "Xindian",
        "新店區公所": "Xindian Dist. Office",
        "七張": "Qizhang",
        "小碧潭": "Xiaobitan",
        "大坪林": "Dapinglin",
        "景美": "Jingmei",
        "萬隆": "Wanlong",
        "公館": "Gongguan",
        "台電大樓": "Taipower Building",
        "古亭": "Guting",
        "小南門": "Xiaonanmen",
        "北門": "Beimen",
        "松江南京": "Songjiang Nanjing",
        "南京復興": "Nanjing Fuxing",
        "台北小巨蛋": "Taipei Arena",
        "南京三民": "Nanjing Sanmin",
        "松山": "Songshan",

        // O (Zhonghe-Xinlu)
        "南勢角": "Nanshijiao",
        "景安": "Jingan",
        "永安市場": "Yongan Market",
        "頂溪": "Dingxi",
        "行天宮": "Xingtian Temple",
        "中山國小": "Zhongshan Elementary School",
        "大橋頭": "Daqiaotou",
        "台北橋": "Taipei Bridge",
        "菜寮": "Cailiao",
        "三重": "Sanchong",
        "先嗇宮": "Xianse Temple",
        "頭前庄": "Touqianzhuang",
        "新莊": "Xinzhuang",
        "輔大": "Fu Jen University",
        "丹鳳": "Danfeng",
        "迴龍": "Huilong",
        "三重國小": "Sanchong Elementary School",
        "三和國中": "Sanhe Junior High School",
        "徐匯中學": "St. Ignatius High School",
        "三民高中": "Sanmin Senior High School",
        "蘆洲": "Luzhou",

        // BR (Wenhu)
        "動物園": "Taipei Zoo",
        "木柵": "Muzha",
        "萬芳社區": "Wanfang Community",
        "萬芳醫院": "Wanfang Hospital",
        "辛亥": "Xinhai",
        "麟光": "Linguang",
        "六張犁": "Liuzhangli",
        "科技大樓": "Technology Building",
        "忠孝復興": "Zhongxiao Fuxing",
        "中山國中": "Zhongshan Jr. High School",
        "松山機場": "Songshan Airport",
        "大直": "Dazhi",
        "劍南路": "Jiannan Rd.",
        "西湖": "Xihu",
        "港墘": "Gangqian",
        "文德": "Wende",
        "內湖": "Neihu",
        "大湖公園": "Dahu Park",
        "葫洲": "Huzhou",
        "東湖": "Donghu",
        "南港軟體園區": "Nangang Software Park",

        // Y (Circular)
        "十四張": "Shisizhang",
        "秀朗橋": "Xiulang Bridge",
        "景平": "Jingping",
        "中和": "Zhonghe",
        "橋和": "Qiaohe",
        "中原": "Zhongyuan",
        "板新": "Banxin",
        "新埔民生": "Xinpu Minsheng",
        "幸福": "Xingfu",
        "新北產業園區": "New Taipei Industrial Park"
    ]

    private static let stationNameZHByEN: [String: String] = {
        var result: [String: String] = [:]
        for (zh, en) in stationNameENByZH {
            result[normalizedLookupKey(en)] = zh
        }
        return result
    }()

    func displayLineName(_ zhLineName: String, languageCode: String? = nil) -> String {
        let lang = languageCode ?? Self.defaultLanguageCode
        guard lang.hasPrefix("en") else { return zhLineName }
        return Self.lineNameENByZH[zhLineName] ?? zhLineName
    }

    func displayStationName(_ zhStationName: String, languageCode: String? = nil) -> String {
        let lang = languageCode ?? Self.defaultLanguageCode
        guard lang.hasPrefix("en") else { return zhStationName }
        return Self.stationNameENByZH[zhStationName] ?? zhStationName
    }

    /// 將使用者輸入（可能是英文）正規化回中文 key，避免 fareDB 查不到。
    func normalizeStationNameToZH(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }
        if Self.stationNameENByZH.keys.contains(trimmed) { return trimmed }
        let normalized = Self.normalizedLookupKey(trimmed)
        return Self.stationNameZHByEN[normalized] ?? trimmed
    }
}
