import SwiftUI
import WebKit
import Combine

// MARK: - 1. 資料模型
struct ParsedTransaction: Identifiable {
    let id = UUID()
    let date: String
    let type: String
    let location: String
    let amount: Int
    
    var isTransport: Bool {
        // 黑名單：過濾掉非交通消費
        let nonTransportKeywords = ["超商", "全家", "全聯", "停車場", "小額扣款", "加值", "售特種票", "美廉社", "麥當勞", "飲料", "自動加值", "特店"]
        if nonTransportKeywords.contains(where: location.contains) { return false }
        
        let transportKeywords = ["捷運", "臺鐵", "台鐵", "客運", "公車", "YouBike", "腳踏車", "輕軌"]
        return transportKeywords.contains(where: location.contains) || type.contains("交通")
    }
    
    // 判斷交通工具類型
    var inferredTransportType: TransportType {
        let locationLower = location.lowercased()
        
        if locationLower.contains("捷運") || locationLower.contains("mrt") {
            if locationLower.contains("台中") || locationLower.contains("taichung") {
                return .tcmrt
            } else if locationLower.contains("高雄") || locationLower.contains("kaohsiung") {
                return .kmrt
            } else if locationLower.contains("淡水") || locationLower.contains("新店") || locationLower.contains("標誌") {
                return .mrt
            }
            return .mrt
        }
        
        if locationLower.contains("台鐵") || locationLower.contains("臺鐵") || locationLower.contains("tra") {
            return .tra
        }
        
        if locationLower.contains("公車") || locationLower.contains("bus") {
            return .bus
        }
        
        if locationLower.contains("客運") || locationLower.contains("coach") {
            return .coach
        }
        
        if locationLower.contains("youbike") || locationLower.contains("腳踏車") || locationLower.contains("bike") {
            return .bike
        }
        
        if locationLower.contains("輕軌") || locationLower.contains("lrt") {
            return .lrt
        }
        
        return .mrt // 預設
    }
}

// MARK: - 2. 可編輯的交易結構
struct EditableTransaction: Identifiable {
    let id = UUID()
    var date: String
    var type: String
    var location: String
    var amount: Int
    var isSelected: Bool = true
    var isTransport: Bool {
        // 黑名單：過濾掉非交通消費
        let nonTransportKeywords = ["超商", "全家", "全聯", "停車場", "小額扣款", "加值", "售特種票", "美廉社", "麥當勞", "飲料", "自動加值", "特店"]
        if nonTransportKeywords.contains(where: location.contains) { return false }
        
        let transportKeywords = ["捷運", "臺鐵", "台鐵", "客運", "公車", "YouBike", "腳踏車", "輕軌"]
        return transportKeywords.contains(where: location.contains) || type.contains("交通")
    }
    
    var inferredTransportType: TransportType {
        let locationLower = location.lowercased()
        
        if locationLower.contains("捷運") || locationLower.contains("mrt") {
            if locationLower.contains("台中") || locationLower.contains("taichung") {
                return .tcmrt
            } else if locationLower.contains("高雄") || locationLower.contains("kaohsiung") {
                return .kmrt
            }
            return .mrt
        }
        
        if locationLower.contains("台鐵") || locationLower.contains("臺鐵") {
            return .tra
        }
        
        if locationLower.contains("公車") {
            return .bus
        }
        
        if locationLower.contains("客運") {
            return .coach
        }
        
        if locationLower.contains("youbike") {
            return .bike
        }
        
        if locationLower.contains("輕軌") {
            return .lrt
        }
        
        return .mrt
    }
    
    init(from transaction: ParsedTransaction) {
        self.date = transaction.date
        self.type = transaction.type
        self.location = transaction.location
        self.amount = transaction.amount
        self.isSelected = transaction.isTransport
    }
}

// MARK: - 3. 主視圖
struct CardScannerView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) var modelContext
    
    @AppStorage("savedEasyCardNumber") private var savedCardNumber: String = ""
    
    @State private var showQueryForm = true
    @State private var showAnalysisSheet = false
    @State private var transactions: [ParsedTransaction] = []
    @State private var editableTransactions: [EditableTransaction] = []
    
    // 查詢表單狀態
    @State private var cardNumber: String = ""
    @State private var birthday: String = "" // MMDD 格式
    @State private var captchaCode: String = ""
    @State private var captchaImage: UIImage?
    @State private var showCaptchaLoading = false
    @State private var errorMessage: String = ""
    
    @StateObject private var webViewModel = WebViewModel()
    let easyCardURL = URL(string: "https://ezweb.easycard.com.tw/search/CardSearch.php")!
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Rectangle()
                    .fill(themeManager.backgroundColor)
                    .ignoresSafeArea()
                
                if showQueryForm {
                    // 顯示查詢表單
                    queryFormView
                } else {
                    // 顯示結果列表
                    transactionListView
                }
            }
            .navigationTitle("import_easy_card")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CaptchaImageLoaded"))) { notification in
            if let image = notification.object as? UIImage {
                self.captchaImage = image
                self.showCaptchaLoading = false
                self.errorMessage = ""
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CaptchaLoadFailed"))) { notification in
            if let error = notification.object as? String {
                self.errorMessage = error
                self.showCaptchaLoading = false
            }
        }
    }
    
    // MARK: - 查詢表單
    private var queryFormView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // 標題
                    VStack(alignment: .leading, spacing: 8) {
                        Text("悠遊卡交易查詢")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Text("輸入卡片資訊查詢交易記錄")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(themeManager.cardBackgroundColor)
                    .cornerRadius(10)
                    
                    // 表單內容
                    VStack(spacing: 20) {
                        // 1. 卡號輸入
                        formFieldSection(
                            label: "外觀卡號",
                            icon: "creditcard.fill",
                            hint: "EasyCard 後 16 位數字"
                        ) {
                            TextField("0000000000000000", text: $cardNumber)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.body)
                                .keyboardType(.numberPad)
                            
                            HStack(spacing: 8) {
                                if !savedCardNumber.isEmpty {
                                    Button(action: {
                                        cardNumber = savedCardNumber
                                    }) {
                                        Text("使用已保存")
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(themeManager.accentColor.opacity(0.15))
                                            .foregroundColor(themeManager.accentColor)
                                            .cornerRadius(5)
                                    }
                                }
                                
                                Button(action: {
                                    if !cardNumber.isEmpty {
                                        savedCardNumber = cardNumber
                                    }
                                }) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 11))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(themeManager.accentColor.opacity(0.15))
                                        .foregroundColor(themeManager.accentColor)
                                        .cornerRadius(5)
                                }
                                .disabled(cardNumber.isEmpty)
                                
                                Spacer()
                            }
                        }
                        
                        // 2. 生日MMDD輸入
                        formFieldSection(
                            label: "生日",
                            icon: "calendar",
                            hint: "月份+日期，例：0515 表示 5 月 15 日"
                        ) {
                            TextField("MMDD", text: $birthday)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.body)
                                .keyboardType(.numberPad)
                                .onChange(of: birthday) { newValue in
                                    // 限制只能輸入 4 位數字
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered.count > 4 {
                                        birthday = String(filtered.prefix(4))
                                    } else {
                                        birthday = filtered
                                    }
                                }
                        }
                        
                        // 3. 驗證碼圖片顯示
                        formFieldSection(
                            label: "驗證碼",
                            icon: "checkmark.shield.fill",
                            hint: "點擊下方按鈕載入驗證碼圖片"
                        ) {
                            VStack(spacing: 12) {
                                if let captchaImage = captchaImage {
                                    Image(uiImage: captchaImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 60)
                                        .border(themeManager.secondaryTextColor.opacity(0.2), width: 1)
                                        .cornerRadius(4)
                                } else if showCaptchaLoading {
                                    HStack {
                                        ProgressView()
                                            .tint(themeManager.accentColor)
                                        Text("載入驗證碼中...")
                                            .font(.caption)
                                            .foregroundColor(themeManager.secondaryTextColor)
                                    }
                                    .frame(height: 60)
                                    .frame(maxWidth: .infinity)
                                    .background(themeManager.cardBackgroundColor)
                                    .cornerRadius(4)
                                } else {
                                    HStack {
                                        Image(systemName: "questionmark.circle.fill")
                                            .foregroundColor(themeManager.secondaryTextColor)
                                        Text("點擊「載入驗證碼」按鈕")
                                            .font(.caption)
                                            .foregroundColor(themeManager.secondaryTextColor)
                                    }
                                    .frame(height: 60)
                                    .frame(maxWidth: .infinity)
                                    .background(themeManager.cardBackgroundColor.opacity(0.5))
                                    .cornerRadius(4)
                                }
                                
                                Button(action: {
                                    loadCaptchaImage()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("載入驗證碼")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 8)
                                    .background(themeManager.accentColor.opacity(0.15))
                                    .foregroundColor(themeManager.accentColor)
                                    .cornerRadius(6)
                                }
                            }
                        }
                        
                        // 4. 驗證碼輸入
                        formFieldSection(
                            label: "驗證碼輸入",
                            icon: "keyboard",
                            hint: "按圖片輸入驗證碼"
                        ) {
                            TextField("輸入上方圖片的驗證碼", text: $captchaCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.body)
                                .keyboardType(.default)
                        }
                        
                        // 錯誤提示
                        if !errorMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(10)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(20)
                }
                .padding(20)
            }
            
            // 隱藏的 WebView（後台加載官網）
            EasyCardWebView(url: easyCardURL, viewModel: webViewModel) { parsedData in
                self.transactions = parsedData
                self.editableTransactions = parsedData.map { EditableTransaction(from: $0) }
                if !parsedData.isEmpty {
                    self.showQueryForm = false
                    self.showAnalysisSheet = true
                }
            }
            .frame(height: 0)
            .opacity(0)
            
            // 底部按鈕
            VStack(spacing: 12) {
                Button(action: {
                    submitQuery()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("開始查詢")
                    }
                    .frame(maxWidth: .infinity)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.vertical, 12)
                    .background(isFormValid ? themeManager.accentColor : themeManager.accentColor.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!isFormValid)
                
                Text("步驟：\n1. 填入卡號（16位）和生日（MMDD 格式）\n2. 點擊「載入驗證碼」\n3. 填入驗證碼後點「開始查詢」")
                    .font(.caption2)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            .padding(20)
        }
    }
    
    // MARK: - 驗證碼載入
    private func loadCaptchaImage() {
        showCaptchaLoading = true
        errorMessage = ""
        
        guard let webView = webViewModel.webView else {
            errorMessage = "網頁未載入，請稍候..."
            showCaptchaLoading = false
            return
        }
        
        // 等待頁面完全載入後再搜尋驗證碼
        let jsScript = """
        (function() {
            // 等待 DOM 和資源完全加載
            function waitForCaptcha(callback, maxAttempts = 10) {
                if (maxAttempts <= 0) {
                    callback(null);
                    return;
                }
                
                var captchaImg = findCaptchaImage();
                if (captchaImg && captchaImg.src) {
                    callback(captchaImg);
                } else {
                    setTimeout(function() {
                        waitForCaptcha(callback, maxAttempts - 1);
                    }, 500);
                }
            }
            
            function findCaptchaImage() {
                // 策略 1: 直接查找 ID 為 imgcode 的圖片（悠遊卡官方網站識別）
                var img = document.getElementById('imgcode');
                if (img && img.src) return img;
                
                // 策略 2: 直接查找 class 為 imgcode 的圖片
                img = document.querySelector('img.imgcode');
                if (img && img.src) return img;
                
                // 策略 3: 查找 ID 為 captcha 的圖片（備選）
                img = document.getElementById('captcha');
                if (img && img.src) return img;
                
                // 策略 4: 查找 name 為 captcha 或 checkword 的圖片
                img = document.querySelector('img[name="captcha"]');
                if (img && img.src) return img;
                
                // 策略 5: 查找包含 captcha 的 src 屬性的圖片
                var imgs = document.querySelectorAll('img');
                for (var i = 0; i < imgs.length; i++) {
                    var src = (imgs[i].src || '').toLowerCase();
                    if (src.includes('captcha') || src.includes('code') || src.includes('verify') || src.includes('random')) {
                        return imgs[i];
                    }
                }
                
                return null;
            }
            
            waitForCaptcha(function(captchaImg) {
                if (captchaImg && captchaImg.src) {
                    var captchaSrc = captchaImg.src;
                    
                    // 如果是 blob URL，使用 Canvas 轉換為 data URL
                    if (captchaSrc.startsWith('blob:')) {
                        var img = new Image();
                        img.onload = function() {
                            var canvas = document.createElement('canvas');
                            canvas.width = img.width;
                            canvas.height = img.height;
                            var ctx = canvas.getContext('2d');
                            ctx.drawImage(img, 0, 0);
                            var dataUrl = canvas.toDataURL('image/png');
                            
                            window.webkit.messageHandlers.captchaHandler.postMessage({
                                status: 'success',
                                captchaSrc: dataUrl,
                                message: '成功取得驗證碼圖片'
                            });
                        };
                        img.onerror = function() {
                            window.webkit.messageHandlers.captchaHandler.postMessage({
                                status: 'error',
                                message: '無法加載驗證碼圖片 (Blob URL 無法轉換)'
                            });
                        };
                        img.src = captchaSrc;
                    } else if (captchaSrc.startsWith('data:')) {
                        // 已經是 data URL，直接發送
                        window.webkit.messageHandlers.captchaHandler.postMessage({
                            status: 'success',
                            captchaSrc: captchaSrc,
                            message: '成功取得驗證碼圖片'
                        });
                    } else {
                        // 如果 src 是相對路徑，轉成絕對路徑
                        if (!captchaSrc.startsWith('http')) {
                            var base = window.location.origin;
                            captchaSrc = base + (captchaSrc.startsWith('/') ? captchaSrc : '/' + captchaSrc);
                        }
                        
                        // 驗證 URL 合法性
                        if (captchaSrc.length > 0) {
                            window.webkit.messageHandlers.captchaHandler.postMessage({
                                status: 'success',
                                captchaSrc: captchaSrc,
                                message: '成功取得驗證碼圖片'
                            });
                        } else {
                            window.webkit.messageHandlers.captchaHandler.postMessage({
                                status: 'error',
                                message: '驗證碼圖片 URL 無效'
                            });
                        }
                    }
                } else {
                    // 搜尋失敗，返回所有圖片資訊用於調試
                    var allImgs = [];
                    var imgs = document.querySelectorAll('img');
                    for (var i = 0; i < Math.min(imgs.length, 10); i++) {
                        allImgs.push({
                            src: imgs[i].src,
                            alt: imgs[i].alt,
                            id: imgs[i].id,
                            class: imgs[i].className
                        });
                    }
                    
                    window.webkit.messageHandlers.captchaHandler.postMessage({
                        status: 'error',
                        message: '找不到 ID=imgcode 的驗證碼圖片，頁面可能未完全加載',
                        totalImages: document.querySelectorAll('img').length,
                        sampleImages: allImgs
                    });
                }
            });
        })();
        """
        
        webView.evaluateJavaScript(jsScript) { _, error in
            if let error = error {
                self.errorMessage = "執行錯誤: \(error.localizedDescription)"
                self.showCaptchaLoading = false
            }
        }
    }
    
    // MARK: - 提交查詢
    private func submitQuery() {
        errorMessage = ""
        
        guard !cardNumber.isEmpty else {
            errorMessage = "請輸入卡號"
            return
        }
        
        guard birthday.count == 4 else {
            errorMessage = "請輸入正確的生日（MMDD，4位數字）"
            return
        }
        
        guard !captchaCode.isEmpty else {
            errorMessage = "請輸入驗證碼"
            return
        }
        
        guard let webView = webViewModel.webView else {
            errorMessage = "網頁未載入"
            return
        }
        
        // JavaScript：自動填入表單並提交
        let jsScript = """
        (function() {
            try {
                // 找尋卡號欄位 (ID: cardIdInput 或 name: card_id)
                var cardInput = document.getElementById('cardIdInput') || document.querySelector('input[name="card_id"]');
                if (cardInput) {
                    cardInput.value = '\(cardNumber)';
                    cardInput.dispatchEvent(new Event('change', { bubbles: true }));
                    cardInput.dispatchEvent(new Event('input', { bubbles: true }));
                }
                
                // 找尋生日欄位 (ID: birthdayInput 或 name: birthday)
                var birthdayInput = document.getElementById('birthdayInput') || document.querySelector('input[name="birthday"]');
                if (birthdayInput) {
                    birthdayInput.value = '\(birthday)';
                    birthdayInput.dispatchEvent(new Event('change', { bubbles: true }));
                    birthdayInput.dispatchEvent(new Event('input', { bubbles: true }));
                }
                
                // 找尋驗證碼欄位 (ID: checkword 或 name: checkword)
                var captchaInput = document.getElementById('checkword') || document.querySelector('input[name="checkword"]');
                if (captchaInput) {
                    captchaInput.value = '\(captchaCode)';
                    captchaInput.dispatchEvent(new Event('change', { bubbles: true }));
                    captchaInput.dispatchEvent(new Event('input', { bubbles: true }));
                }
                
                // 找尋並點擊查詢按鈕 (ID: btnSearch)
                var searchButton = document.getElementById('btnSearch');
                if (searchButton) {
                    searchButton.click();
                    window.webkit.messageHandlers.queryHandler.postMessage('query_submitted');
                } else {
                    // 備選：查找所有按鈕
                    var buttons = document.querySelectorAll('button, input[type="button"], input[type="submit"]');
                    var buttonFound = false;
                    for (var i = 0; i < buttons.length; i++) {
                        var btnText = buttons[i].value || buttons[i].textContent || '';
                        if (btnText.includes('查詢') || btnText.includes('查询') || 
                            btnText.includes('搜尋') || btnText.includes('搜索') ||
                            btnText.includes('Search') || btnText.includes('Query')) {
                            buttons[i].click();
                            buttonFound = true;
                            break;
                        }
                    }
                    
                    if (buttonFound) {
                        window.webkit.messageHandlers.queryHandler.postMessage('query_submitted');
                    } else {
                        window.webkit.messageHandlers.queryHandler.postMessage('button_not_found');
                    }
                }
            } catch (e) {
                window.webkit.messageHandlers.queryHandler.postMessage('error: ' + e.toString());
            }
        })();
        """
        
        webView.evaluateJavaScript(jsScript) { _, error in
            if let error = error {
                self.errorMessage = "提交失敗: \(error.localizedDescription)"
            } else {
                print("表單已提交，等待頁面載入結果...")
                // 延遲 7 秒後開始抓取資料，確保頁面完全載入結果
                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                    print("開始抓取交易資料...")
                    self.webViewModel.extractData()
                }
            }
        }
    }
    
    // MARK: - 表單驗證
    private var isFormValid: Bool {
        !cardNumber.isEmpty && birthday.count == 4 && !captchaCode.isEmpty && captchaImage != nil
    }
    
    // MARK: - 表單欄位公用樣式
    @ViewBuilder
    private func formFieldSection<Content: View>(
        label: String,
        icon: String,
        hint: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.accentColor)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
            }
            .foregroundColor(themeManager.primaryTextColor)
            
            Text(hint)
                .font(.caption2)
                .foregroundColor(themeManager.secondaryTextColor)
            
            content()
        }
        .padding(12)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.secondaryTextColor.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - 交易列表
    private var transactionListView: some View {
        VStack(spacing: 0) {
            // 統計信息
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("截取結果")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                        Text("\(editableTransactions.count) 筆交易")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("可導入")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                        Text("\(editableTransactions.filter { $0.isTransport }.count) 筆")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.accentColor)
                    }
                }
                .padding(12)
                .background(themeManager.cardBackgroundColor)
                .cornerRadius(10)
            }
            .padding(20)
            
            // 交易列表
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach($editableTransactions) { $transaction in
                        TransactionRowView(transaction: $transaction, themeManager: themeManager)
                    }
                }
                .padding(20)
            }
            
            // 底部按鈕
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: {
                        showQueryForm = true
                        showAnalysisSheet = false
                        editableTransactions = []
                    }) {
                        Text("重新查詢")
                            .frame(maxWidth: .infinity)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.vertical, 12)
                            .background(themeManager.cardBackgroundColor)
                            .foregroundColor(themeManager.primaryTextColor)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        importTransactions()
                        showQueryForm = true
                        showAnalysisSheet = false
                        editableTransactions = []
                    }) {
                        Text("確認匯入")
                            .frame(maxWidth: .infinity)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.vertical, 12)
                            .background(themeManager.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(editableTransactions.filter { $0.isTransport && $0.isSelected }.isEmpty)
                }
                .padding(20)
            }
        }
    }
    
    // MARK: - 匯入功能
    private func importTransactions() {
        let selectedTrips = editableTransactions
            .filter { $0.isTransport && $0.isSelected }
            .compactMap { transaction -> Trip? in
                guard let date = DateFormatter.defaultFormatter.date(from: transaction.date) else { return nil }
                
                // 根據地點推斷運具類型
                let transportType = transaction.inferredTransportType
                
                let trip = Trip(
                    userId: auth.currentUser?.id ?? "unknown",
                    createdAt: date,
                    type: transportType,
                    originalPrice: transaction.amount,
                    paidPrice: transaction.amount,
                    isTransfer: false,
                    isFree: transaction.amount == 0,
                    startStation: "",
                    endStation: transaction.location,
                    routeId: "",
                    note: "自悠遊卡匯入: \(transaction.location)"
                )
                
                return trip
            }
        
        for trip in selectedTrips {
            appViewModel.addTrip(trip)
        }
    }
}

// MARK: - 交易行列表示
struct TransactionRowView: View {
    @Binding var transaction: EditableTransaction
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 選擇按鈕
                Image(systemName: transaction.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(transaction.isSelected ? themeManager.accentColor : themeManager.secondaryTextColor)
                    .onTapGesture {
                        transaction.isSelected.toggle()
                    }
                
                // 運具圖示
                let transportType = transaction.inferredTransportType
                ZStack {
                    Circle()
                        .fill(transportType.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: transportType.systemIconName)
                        .font(.system(size: 16))
                        .foregroundColor(transportType.color)
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(transaction.location)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryTextColor)
                            .lineLimit(1)
                        
                        if !transaction.isTransport {
                            Text("非交通")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text(transaction.date)
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        Text("•")
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        Text(transaction.type)
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
                
                Spacer()
                
                // 金額
                Text("$\(transaction.amount)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(transaction.amount == 0 ? themeManager.accentColor : themeManager.primaryTextColor)
            }
            .padding(12)
            .background(themeManager.cardBackgroundColor)
            .cornerRadius(10)
        }
    }
}

// MARK: - WebView 控制器
class WebViewModel: ObservableObject {
    var webView: WKWebView?
    var captchaCallback: ((String) -> Void)?
    
    init() {}
    
    func extractData() {
        guard let webView = webView else {
            print("錯誤：WebView 尚未準備好")
            return
        }
        
        let jsScript = """
        (function() {
            try {
                console.log('頁面 title:', document.title);
                console.log('頁面 readyState:', document.readyState);
                
                // 策略 1: 查找 class="tbl_product" 的表格
                var tables = document.querySelectorAll('.tbl_product');
                console.log('找到 .tbl_product 表格數量:', tables.length);
                
                // 策略 2: 如果找不到，查找所有 table
                if (tables.length === 0) {
                    var allTables = document.querySelectorAll('table');
                    console.log('找到總表格數量:', allTables.length);
                    
                    // 找尋包含交易數據的表格
                    for (var t = 0; t < allTables.length; t++) {
                        var tableText = allTables[t].textContent;
                        if (tableText.includes('交易時間') || tableText.includes('交易金額') || tableText.includes('交易場所')) {
                            tables = [allTables[t]];
                            console.log('找到交易表格！');
                            break;
                        }
                    }
                }
                
                if (tables.length === 0) {
                    return "找不到表格。頁面上共有 " + document.querySelectorAll('table').length + " 個表格，可能查詢未成功";
                }
                
                var extractedData = [];
                
                for (var t = 0; t < tables.length; t++) {
                    var rows = tables[t].querySelectorAll('tr');
                    console.log('表格 ' + t + ' 有 ' + rows.length + ' 行');
                    
                    for (var i = 0; i < rows.length; i++) {
                        var cols = rows[i].querySelectorAll('td');
                        
                        if (cols.length >= 4) {
                            var dateText = cols[0].textContent.trim();
                            var typeText = cols[1].textContent.trim();
                            var locText = cols[2].textContent.trim();
                            var amtText = cols[3].textContent.trim();
                            
                            // 跳過表頭行
                            if (dateText && !dateText.includes('交易時間')) {
                                extractedData.push({
                                    "date": dateText,
                                    "type": typeText,
                                    "location": locText,
                                    "amount": amtText
                                });
                            }
                        }
                    }
                }
                
                console.log('最終提取資料數:', extractedData.length);
                
                if (extractedData.length > 0) {
                    window.webkit.messageHandlers.easycardHandler.postMessage(extractedData);
                    return "成功發送 " + extractedData.length + " 筆資料";
                } else {
                    return "表格內無資料。請確認：1) 卡號生日正確，2) 驗證碼正確，3) 查詢成功";
                }
            } catch (e) {
                return "解析錯誤: " + e.toString();
            }
        })();
        """
        
        webView.evaluateJavaScript(jsScript) { result, error in
            if let error = error {
                print("JS 執行失敗: \(error.localizedDescription)")
            } else {
                print("JS 執行結果: \(result ?? "無回傳值")")
            }
        }
    }
}

// MARK: - 網頁視圖實作
struct EasyCardWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var viewModel: WebViewModel
    let onDataExtracted: ([ParsedTransaction]) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        userContentController.add(context.coordinator, name: "easycardHandler")
        userContentController.add(context.coordinator, name: "captchaHandler")
        userContentController.add(context.coordinator, name: "queryHandler")
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        
        DispatchQueue.main.async {
            self.viewModel.webView = webView
        }
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url == nil {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        let parent: EasyCardWebView
        
        init(_ parent: EasyCardWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // 處理交易資料
            if message.name == "easycardHandler",
               let dataArray = message.body as? [[String: String]] {
                
                let transactions = dataArray.compactMap { dict -> ParsedTransaction? in
                    guard let date = dict["date"],
                          let type = dict["type"],
                          let location = dict["location"],
                          let amountStr = dict["amount"] else { return nil }
                    
                    let cleanAmountStr = amountStr.replacingOccurrences(of: ",", with: "")
                    let amount = Int(cleanAmountStr) ?? 0
                    
                    return ParsedTransaction(date: date, type: type, location: location, amount: amount)
                }
                
                DispatchQueue.main.async {
                    self.parent.onDataExtracted(transactions)
                }
            }
            
            // 處理驗證碼圖片
            if message.name == "captchaHandler",
               let response = message.body as? [String: Any] {
                
                if let status = response["status"] as? String, status == "success",
                   let captchaSrc = response["captchaSrc"] as? String {
                    
                    print("驗證碼 URL: \(String(captchaSrc.prefix(100)))...")
                    
                    // 檢查是否為 data URL
                    if captchaSrc.hasPrefix("data:image") {
                        // 處理 data URL: data:image/png;base64,...
                        if let base64Part = captchaSrc.components(separatedBy: ",").last,
                           let imageData = Data(base64Encoded: base64Part) {
                            if let uiImage = UIImage(data: imageData) {
                                print("驗證碼圖片加載成功 (Data URL)")
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("CaptchaImageLoaded"),
                                        object: uiImage
                                    )
                                }
                                return
                            }
                        }
                        
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("CaptchaLoadFailed"),
                                object: "無法解析驗證碼圖片 (Data URL)"
                            )
                        }
                        return
                    }
                    
                    // 從 HTTP/HTTPS URL 下載驗證碼圖片
                    guard let url = URL(string: captchaSrc) else {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("CaptchaLoadFailed"),
                                object: "驗證碼 URL 無效"
                            )
                        }
                        return
                    }
                    
                    DispatchQueue.global().async {
                        var request = URLRequest(url: url)
                        request.timeoutInterval = 10
                        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                        
                        URLSession.shared.dataTask(with: request) { data, response, error in
                            if let error = error {
                                print("下載驗證碼失敗: \(error.localizedDescription)")
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("CaptchaLoadFailed"),
                                        object: "下載驗證碼失敗: \(error.localizedDescription)"
                                    )
                                }
                                return
                            }
                            
                            if let data = data, let uiImage = UIImage(data: data) {
                                print("驗證碼圖片加載成功 (HTTP URL)")
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("CaptchaImageLoaded"),
                                        object: uiImage
                                    )
                                }
                            } else {
                                print("無法從數據創建圖片")
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("CaptchaLoadFailed"),
                                        object: "無法解析驗證碼圖片"
                                    )
                                }
                            }
                        }.resume()
                    }
                } else {
                    var errorMsg = (response["message"] as? String) ?? "未知錯誤"
                    
                    // 添加調試信息
                    if let totalImages = response["totalImages"] as? Int {
                        errorMsg += " (頁面中找到 \(totalImages) 張圖片)"
                    }
                    
                    if let sampleImages = response["sampleImages"] as? [[String: String]] {
                        print("頁面圖片範例:")
                        for (index, img) in sampleImages.enumerated() {
                            print("  圖片 \(index): src=\(img["src"] ?? "N/A"), alt=\(img["alt"] ?? "N/A")")
                        }
                    }
                    
                    print("驗證碼載入失敗: \(errorMsg)")
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CaptchaLoadFailed"),
                        object: errorMsg
                    )
                }
            }
            
            // 處理查詢提交
            if message.name == "queryHandler",
               let result = message.body as? String {
                print("查詢結果: \(result)")
            }
        }
    }
}

// MARK: - 幫助方法
extension DateFormatter {
    static let defaultFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
}
