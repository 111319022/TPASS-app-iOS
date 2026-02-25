import SwiftUI
import Foundation

struct TransferIntroductionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var auth: AuthService

    private var currentIdentity: Identity {
        auth.currentUser?.identity ?? .adult
    }

    private static func discountDetailText(for transferType: TransferDiscountType, identity: Identity) -> Text {
        let amount = transferType.discount(for: identity)
        let format = NSLocalizedString("transfer_intro_discount_format", comment: "")
        return Text(String(format: format, amount))
    }

    //轉乘介紹
    private let sections: [TransferIntroSection] = [
        
        //基北北桃
        TransferIntroSection(
            title: "plan_north",
            subtitle: "taipei_new_taipei_taoyuan_keelung",
            rules: [
                TransferRule(
                    leftIcon: "tram.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_Taipei_Metro_Bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_Taipei_Metro_Bus_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_Taipei_Metro_Bus_student"),
                    ],
                    arrowType: .double
                ),
                TransferRule(
                    leftIcon: "bus.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_Taipei_Bus_Metro Bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_Taipei_Bus_MetroBus_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_Taipei_Bus_MetroBus_student"),
                    ],
                    arrowType: .double
                ),
            ]
        ),
        
        //桃竹竹
        TransferIntroSection(
            title: "plan_taoyuan_hsinchu",
            subtitle: "taoyuan_hsinchu",
            rules: [
                TransferRule(
                    leftIcon: "airplane.departure",
                    rightIcon: "bus.fill",
                    title: "TransGuide_TYMRT_Bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_TYMRT_Bus_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_TYMRT_Bus_student"),
                    ],
                    arrowType: .single
                ),
                TransferRule(
                    leftIcon: "bus.fill",
                    rightIcon: "airplane.departure",
                    title: "TransGuide_Bus_TYMRT",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_Bus_TYMRT_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_Bus_TYMRT_student"),
                    ],
                    arrowType: .single
                ),
                TransferRule(
                    leftIcon: "bus.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_Hsinchu_Bus_Bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_Hsinchu_Bus_Bus"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_Hsinchu_Bus_Bus"),
                    ],
                    arrowType: .single
                ),
            ]
        ),

        //桃竹竹苗
        TransferIntroSection(
            title: "plan_TaoMiao",
            subtitle: "taoyuan_hsinchu_miaoli",
            rules: [
                TransferRule(
                    leftIcon: "airplane.departure",
                    rightIcon: "bus.fill",
                    title: "TransGuide_TYMRT_Bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_TYMRT_Bus_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_TYMRT_Bus_student"),
                    ],
                    arrowType: .single
                ),
                TransferRule(
                    leftIcon: "bus.fill",
                    rightIcon: "airplane.departure",
                    title: "TransGuide_Bus_TYMRT",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_Bus_TYMRT_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_Bus_TYMRT_student"),
                    ],
                    arrowType: .single
                ),
                TransferRule(
                    leftIcon: "bus.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_Hsinchu_Bus_Bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_Hsinchu_Bus_Bus"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_Hsinchu_Bus_Bus"),
                    ],
                    arrowType: .single
                ),
            ]
        ),

        //竹竹苗
        TransferIntroSection(
            title: "plan_ZhuMiao",
            subtitle: "hsinchu_miaoli",
            rules: [
                TransferRule(
                    leftIcon: "bus.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_Hsinchu_Bus_Bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_Hsinchu_Bus_Bus"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_Hsinchu_Bus_Bus"),
                    ],
                    arrowType: .single
                ),
            ]
        ),

        //北宜跨城際及雙北
        TransferIntroSection(
            title: "plan_BeiYiMegaPASS",
            subtitle: "yilan_taipei_megapass",
            rules: [
                TransferRule(
                    leftIcon: "tram.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_Taipei_Metro_Bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_Taipei_Metro_Bus_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_Taipei_Metro_Bus_student"),
                    ],
                    arrowType: .double
                ),
                TransferRule(
                    leftIcon: "bus.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_Taipei_Bus_Metro Bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_Taipei_Bus_MetroBus_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_Taipei_Bus_MetroBus_student"),
                    ],
                    arrowType: .double
                ),
                TransferRule(
                    leftIcon: "bus.doubledecker.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_transfer_yilan",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_yilan_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_yilan_student"),
                    ],
                    arrowType: .single
                ),
            ]
        ),

        //北宜跨城際
        TransferIntroSection(
            title: "plan_BeiYi",
            subtitle: "yilan_taipei",
            rules: [
                TransferRule(
                    leftIcon: "tram.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_Taipei_Metro_Bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_Taipei_Metro_Bus_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_Taipei_Metro_Bus_student"),
                    ],
                    arrowType: .double
                ),
                TransferRule(
                    leftIcon: "bus.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_Taipei_Bus_Metro Bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_Taipei_Bus_MetroBus_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_Taipei_Bus_MetroBus_student"),
                    ],
                    arrowType: .double
                ),
                   TransferRule(
                    leftIcon: "bus.doubledecker.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_transfer_yilan",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_yilan_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_yilan_student"),
                    ],
                    arrowType: .single
                ),
            ]
        ),

        //宜蘭
        TransferIntroSection(
            title: "plan_Yilan",
            subtitle: "yilan",
            rules: [
                   TransferRule(
                    leftIcon: "bus.doubledecker.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_transfer_yilan",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_yilan_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_yilan_student"),
                    ],
                    arrowType: .single
                ),
            ]
        ),

        //宜蘭好行三日券
        TransferIntroSection(
            title: "plan_Yilan3Days",
            subtitle: "yilan_3_days",
            rules: [
                   TransferRule(
                    leftIcon: "bus.doubledecker.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_transfer_yilan",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_yilan_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_yilan_student"),
                    ],
                    arrowType: .single
                ),
            ]
        ),

        //中彰投苗(非市民)
        TransferIntroSection(
            title: "plan_central_non_resident",
            subtitle: "taichung_changhua_nantou_miaoli_non_resident",
            rules: [
                TransferRule(
                    leftIcon: "xmark.circle.fill",
                    rightIcon: "",
                    showArrow: false,
                    title: "no_transfer_discount",
                    detail: "keep_original_price",
                    arrowType: .double
                ),
            ]
        ),

        //中彰投苗(市民)
        TransferIntroSection(
            title: "plan_central_resident",
            subtitle: "taichung_changhua_nantou_miaoli_resident",
            rules: [
                TransferRule(
                    leftIcon: "bus.fill",
                    rightIcon: "",
                    rightLabel: "10km+",
                    showArrow: false,
                    title: "TransGuide_transfer_taichung_citizen",
                    detailTextProvider: { identity in
                        TransferIntroductionView.discountDetailText(for: .taichung, identity: identity)
                    },
                    arrowType: .double
                ),
            ]
        ),

        //南高屏
        TransferIntroSection(
            title: "plan_south",
            subtitle: "kaohsiung_tainan_pingtung",
            rules: [
                TransferRule(
                    leftIcon: "tram.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_transfer_kaohsiung_mrt_bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_kaohsiung_mrt_bus_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_kaohsiung_mrt_bus_student"),
                    ],
                    arrowType: .double
                ),
                TransferRule(
                    leftIcon: "bicycle",
                    rightIcon: "tram.fill",
                    title: "TransGuide_transfer_kaohsiung_bike",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_kaohsiung_bike"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_kaohsiung_bike"),
                    ],
                    arrowType: .double
                ),
                TransferRule(
                    leftIcon: "train.side.front.car",
                    rightIcon: "bus.fill",
                    title: "TransGuide_transfer_tainan_tra_bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_tainan_tra_bus"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_tainan_tra_bus"),
                    ],
                    arrowType: .single
                ),
            ]
        ),

        //高雄
        TransferIntroSection(
            title: "plan_kaohsiung",
            subtitle: "kaohsiung_only",
            rules: [
                TransferRule(
                    leftIcon: "tram.fill",
                    rightIcon: "bus.fill",
                    title: "TransGuide_transfer_kaohsiung_mrt_bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_kaohsiung_mrt_bus_adult"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_kaohsiung_mrt_bus_student"),
                    ],
                    arrowType: .double
                ),
                TransferRule(
                    leftIcon: "bicycle",
                    rightIcon: "tram.fill",
                    title: "TransGuide_transfer_kaohsiung_bike",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_kaohsiung_bike"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_kaohsiung_bike"),
                    ],
                    arrowType: .double
                ),
            ]
        ),
        
        //台南
        TransferIntroSection(
            title: "plan_tainan",
            subtitle: "TransGuide_tainan",
            rules: [
                TransferRule(
                    leftIcon: "train.side.front.car",
                    rightIcon: "bus.fill",
                    title: "TransGuide_transfer_tainan_tra_bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_tainan_tra_bus"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_tainan_tra_bus"),
                    ],
                    arrowType: .single
                ),
            ]
        ),
        
        //嘉南
        TransferIntroSection(
            title: "plan_chiayi_tainan",
            subtitle: "TransGuide_Chayi_tainan",
            rules: [
                TransferRule(
                    leftIcon: "train.side.front.car",
                    rightIcon: "bus.fill",
                    title: "TransGuide_transfer_tainan_tra_bus",
                    detailByIdentity: [
                        Identity.adult: LocalizedStringKey("TransGuideInfo_tainan_tra_bus"),
                        Identity.student: LocalizedStringKey("TransGuideInfo_tainan_tra_bus"),
                    ],
                    arrowType: .single
                ),
            ]
        ),
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("transfer_intro_summary")
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)

                    HStack(spacing: 6) {
                        Text("transfer_intro_identity_label")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(currentIdentity.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            ForEach(sections.indices, id: \.self) { sectionIndex in
                let section = sections[sectionIndex]
                Section {
                    ForEach(section.rules.indices, id: \.self) { ruleIndex in
                        TransferRuleRow(rule: section.rules[ruleIndex], identity: currentIdentity)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        Text(section.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listSectionSeparator(.hidden)
            }

            Section(footer: Text("transfer_intro_footer").font(.footnote).foregroundColor(.secondary)) {
                EmptyView()
            }
        }
        .navigationTitle("transfer_intro_title")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
    }
}

private struct TransferRuleRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    let rule: TransferRule
    let identity: Identity

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: rule.leftIcon)
                if rule.showArrow {
                    Image(systemName: rule.arrowType == .single ? "arrow.right" : "arrow.left.and.right")
                }
                if !rule.rightIcon.isEmpty {
                    Image(systemName: rule.rightIcon)
                }
                if let rightLabel = rule.rightLabel {
                    Text(rightLabel)
                        .font(.caption2)
                }
            }
            .foregroundColor(themeManager.accentColor)
            .frame(width: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(rule.title)
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)

                if let detailText = rule.detailText(for: identity) {
                    detailText
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 8)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct TransferIntroSection {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let rules: [TransferRule]
}

enum TransferArrowType {
    case single   // →
    case double   // ↔
}

private struct TransferRule {
    let leftIcon: String
    let rightIcon: String
    let rightLabel: String?
    let showArrow: Bool
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?
    var detailByIdentity: [Identity: LocalizedStringKey]? = nil
    var detailTextProvider: ((Identity) -> Text)? = nil
    var arrowType: TransferArrowType = .double

    init(
        leftIcon: String,
        rightIcon: String,
        rightLabel: String? = nil,
        showArrow: Bool = true,
        title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        detailByIdentity: [Identity: LocalizedStringKey]? = nil,
        detailTextProvider: ((Identity) -> Text)? = nil,
        arrowType: TransferArrowType = .double
    ) {
        self.leftIcon = leftIcon
        self.rightIcon = rightIcon
        self.rightLabel = rightLabel
        self.showArrow = showArrow
        self.title = title
        self.detail = detail
        self.detailByIdentity = detailByIdentity
        self.detailTextProvider = detailTextProvider
        self.arrowType = arrowType
    }

    func detailText(for identity: Identity) -> Text? {
        if let detailTextProvider {
            return detailTextProvider(identity)
        }
        if let detailByIdentity, let value = detailByIdentity[identity] {
            return Text(value)
        }
        if let detail {
            return Text(detail)
        }
        return nil
    }
}

#Preview {
    NavigationStack {
        TransferIntroductionView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AuthService.shared)
    }
}
