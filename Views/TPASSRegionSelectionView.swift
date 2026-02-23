import SwiftUI

struct TPASSRegionSelectionView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    private func descriptionKey(for region: TPASSRegion) -> LocalizedStringKey {
        switch region {
        case .north:
            return "taipei_new_taipei_taoyuan_keelung"
        case .taoZhuZhu:
            return "taoyuan_hsinchu"
        case .taoZhuZhuMiao:
            return "taoyuan_hsinchu_miaoli"
        case .zhuZhuMiao:
            return "hsinchu_miaoli"
        case .beiYiMegaPASS:
            return "yilan_taipei_megapass"
        case .beiYi:
            return "yilan_taipei"
        case .yilan:
            return "yilan"
        case .yilan3Days:
            return "yilan_3_days"
        case .central:
            return "taichung_changhua_nantou_miaoli_non_resident"
        case .centralCitizen:
            return "taichung_changhua_nantou_miaoli_resident"
        case .south:
            return "kaohsiung_tainan_pingtung"
        case .kaohsiung:
            return "kaohsiung_only"
        case .flexible:
            // 🔧 彈性記帳週期不應該出現在這個列表中
            return ""
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("region_intro")) {
                ForEach(TPASSRegion.allCases, id: \.self) { region in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(region.displayNameKey)
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                            Text(descriptionKey(for: region))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("$\(region.monthlyPrice)")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
            Section(footer: Text("more_plans_footer").font(.footnote).foregroundColor(.secondary)) {
                EmptyView()
            }
        }
        .navigationTitle("region_selection_ title")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
    }
}

#Preview {
    NavigationStack {
        TPASSRegionSelectionView()
            .environmentObject(ThemeManager.shared)
    }
}
