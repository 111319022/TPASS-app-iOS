import SwiftUI

struct CommuterRoutePickerOverlay: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: AppViewModel
    var onSelectExisting: ((String) -> Void)?
    var onAddNew: (() -> Void)?
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("加入通勤路線")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text("選擇現有通勤路線或新增")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                VStack(spacing: 12) {
                    let names = Array(Set(viewModel.commuterRoutes.map { $0.name })).sorted()
                    
                    ForEach(names, id: \.self) { name in
                        Button(action: {
                            onSelectExisting?(name)
                            isPresented = false
                        }) {
                            Text(name)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(UIColor.systemGray6))
                                .foregroundColor(.black)
                                .cornerRadius(8)
                                .font(.system(.body, design: .default))
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Button(action: {
                    onAddNew?()
                    isPresented = false
                }) {
                    Text("新增其他")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.systemBlue).opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                        .font(.system(.body, design: .default))
                        .fontWeight(.semibold)
                }
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("取消")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.systemGray6))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .font(.system(.body, design: .default))
                }
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding(24)
        }
    }
}
