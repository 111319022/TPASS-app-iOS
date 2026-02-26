import SwiftUI

struct TransferTypeSelectionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var auth: AuthService // 引入 Auth 服務以獲取正確身份
    
    let trip: Trip
    let region: TPASSRegion
    let viewModel: AppViewModel
    @Binding var isPresented: Bool
    let onSelected: (TransferDiscountType?) -> Void
    
    // 獲取當前使用者身份，預設為成人
    private var currentIdentity: Identity {
        auth.currentUser?.identity ?? .adult
    }
    
    // 根據市民設定篩選轉乘類型
    private var filteredTransferTypes: [TransferDiscountType] {
        let allTypes = region.availableTransferTypes
        let userCity = auth.currentUser?.citizenCity
        
        // 如果用戶未設定市民縣市（nil），顯示全部
        guard let userCity = userCity else {
            return allTypes
        }
        
        // 如果用戶有設定市民縣市，只顯示：
        // 1. 非市民限定的方案
        // 2. 符合用戶所屬縣市的市民限定方案
        return allTypes.filter { transferType in
            if let requiredCity = transferType.citizenRequirement {
                return requiredCity == userCity
            }
            return true  // 非市民限定的方案都顯示
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 可用的轉乘類型列表
                Section {
                   
                    ForEach(filteredTransferTypes, id: \.self) { transferType in
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            
                            // 假設 AppViewModel 有實作 setTransferType 方法
                            viewModel.setTransferType(trip, transferType: transferType)
                            
                            onSelected(transferType)
                            isPresented = false
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transferType.displayNameKey(for: currentIdentity))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    // [修正] 手動計算折扣後價格 (取代不存在的 getDiscountedPrice)
                                    let discountedPrice = max(0, trip.originalPrice - transferType.discount(for: currentIdentity))
                                    
                                    // 雙語化：使用本地化字串
                                    HStack(spacing: 4) {
                                        Text("discounted_price")
                                            .foregroundColor(.secondary)
                                        Text(":")
                                            .foregroundColor(.secondary)
                                        Text(String(format: NSLocalizedString("price_format", comment: ""), discountedPrice))
                                            .foregroundColor(.secondary)
                                        Text("(")
                                            .foregroundColor(.secondary)
                                        Text("original_price_short")
                                            .foregroundColor(.secondary)
                                        Text(":")
                                            .foregroundColor(.secondary)
                                        Text(String(format: NSLocalizedString("price_format", comment: ""), trip.originalPrice))
                                            .foregroundColor(.secondary)
                                        Text(")")
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption)
                                }
                                
                                Spacer()
                                
                                // 顯示目前選擇的打勾符號
                                if trip.transferDiscountType == transferType {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                    }
                }
                
                // 取消轉乘選項
                Section {
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        
                        // 假設 AppViewModel 有實作 setTransferType 方法
                        viewModel.setTransferType(trip, transferType: nil)
                        
                        onSelected(nil)
                        isPresented = false
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("no_transfer_discount")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                // 雙語化：使用本地化字串
                                HStack(spacing: 4) {
                                    Text("keep_original_price")
                                        .foregroundColor(.secondary)
                                    Text(":")
                                        .foregroundColor(.secondary)
                                    Text(String(format: NSLocalizedString("price_format", comment: ""), trip.originalPrice))
                                        .foregroundColor(.secondary)
                                }
                                .font(.caption)
                            }
                            
                            Spacer()
                            
                            if trip.transferDiscountType == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
                
                // 底部空白區域，避免被切到
                Color.clear
                    .frame(height: 20)
                    .listRowBackground(Color.clear)
            }
            .navigationTitle("select_transfer_type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
