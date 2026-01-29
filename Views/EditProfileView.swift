import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var selectedAvatar: String = "person.circle.fill"
    @State private var isLoading = false
    
    // 🎨 內建的頭像選項
    let avatars = [
        "person.crop.circle.fill",
        "studentdesk",
        "briefcase.fill",
        "tram.circle.fill",
        "figure.walk.circle.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "cat.circle.fill",
        "pawprint.circle.fill"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // 1. 頭像選擇區
                Section(header: Text("選擇頭像")) {
                    VStack(spacing: 20) {
                        // 顯示目前選中的大頭像
                        if selectedAvatar.contains("http") {
                            // 如果是網址 (原廠頭像)
                            AsyncImage(url: URL(string: selectedAvatar)) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Image(systemName: "person.circle.fill").foregroundColor(.gray)
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .padding(.top, 10)
                        } else {
                            // 如果是內建圖示
                            Image(systemName: selectedAvatar)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(Color(hex: "#d97761"))
                                .padding(.top, 10)
                        }
                        
                        // 🔥 新增：恢復原廠頭像按鈕
                        Button {
                            restoreOriginalAvatar()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                Text("使用 Google / Apple 原本頭像")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        .padding(.bottom, 5)

                        Divider()
                        
                        // 頭像選擇網格
                        LazyVGrid(columns:Array(repeating: GridItem(.flexible()), count: 5), spacing: 15) {
                            ForEach(avatars, id: \.self) { avatar in
                                Image(systemName: avatar)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(selectedAvatar == avatar ? Color(hex: "#d97761") : .gray.opacity(0.3))
                                    .onTapGesture {
                                        withAnimation { selectedAvatar = avatar }
                                    }
                            }
                        }
                        .padding(.bottom, 10)
                    }
                }
                
                // 2. 名稱編輯區
                Section(header: Text("暱稱")) {
                    TextField("請輸入您的暱稱", text: $name)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("編輯個人檔案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        saveProfile()
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .onAppear {
                if let user = auth.currentUser {
                    self.name = user.displayName ?? ""
                    if let photoStr = user.photoURL?.absoluteString {
                        self.selectedAvatar = photoStr
                    }
                }
            }
        }
    }
    
    // 🔥 恢復預設頭像邏輯
    func restoreOriginalAvatar() {
        // 恢復到預設的頭像
        self.selectedAvatar = "person.circle.fill"
    }
    
    func saveProfile() {
        guard auth.currentUser?.id != nil else { return }
        isLoading = true
        
        // 本地儲存用戶名稱
        if var user = auth.currentUser {
            user.email = name
            auth.currentUser = user
            auth.saveLocalUser()
        }
        
        isLoading = false
        dismiss()
    }
}
