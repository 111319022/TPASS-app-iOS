import SwiftUI
import SwiftData

// MARK: - 卡片管理主頁面
struct TransitCardManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \TransitCard.createdAt, order: .reverse) private var cards: [TransitCard]
    
    @State private var showAddCardSheet = false
    @State private var selectedCardForEdit: TransitCard? = nil
    
    var body: some View {
        List {
            if cards.isEmpty {
                emptyStateView
            } else {
                ForEach(cards) { card in
                    Button {
                        selectedCardForEdit = card
                    } label: {
                        TransitCardRow(card: card)
                    }
                }
                .onDelete(perform: deleteCards)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
        .navigationTitle("transit_card_management")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddCardSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddCardSheet) {
            AddTransitCardView()
        }
        .sheet(item: $selectedCardForEdit) { card in
            EditTransitCardView(card: card)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 50))
                .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
            
            Text("no_cards_yet")
                .font(.headline)
                .foregroundColor(themeManager.primaryTextColor)
            
            Text("no_cards_description")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showAddCardSheet = true
            } label: {
                Text("create_first_card")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(themeManager.accentColor)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }
    
    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(cards[index])
        }
    }
}

// MARK: - 卡片列表行
struct TransitCardRow: View {
    let card: TransitCard
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // 卡片圖示
            Image(systemName: card.type == .tpass ? "creditcard.fill" : "creditcard")
                .font(.title2)
                .foregroundColor(card.type == .tpass ? themeManager.accentColor : .secondary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text(card.type.displayName)
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 新增卡片頁面
struct AddTransitCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var cardName: String = ""
    @State private var cardType: TransitCardType = .custom
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("card_info")) {
                    TextField("card_name_placeholder", text: $cardName)
                    
                    Picker("card_type", selection: $cardType) {
                        ForEach(TransitCardType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundColor)
            .navigationTitle("add_card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save") {
                        saveCard()
                    }
                    .fontWeight(.semibold)
                    .disabled(cardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveCard() {
        let trimmedName = cardName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newCard = TransitCard(name: trimmedName, type: cardType, initialBalance: 0)
        modelContext.insert(newCard)
        
        HapticManager.shared.impact(style: .medium)
        dismiss()
    }
}

// MARK: - 編輯卡片頁面
struct EditTransitCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var themeManager: ThemeManager
    
    let card: TransitCard
    
    @State private var cardName: String
    @State private var cardType: TransitCardType
    @State private var showDeleteConfirmation = false
    
    init(card: TransitCard) {
        self.card = card
        _cardName = State(initialValue: card.name)
        _cardType = State(initialValue: card.type)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("card_info")) {
                    TextField("card_name_placeholder", text: $cardName)
                    
                    Picker("card_type", selection: $cardType) {
                        ForEach(TransitCardType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("delete_card")
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundColor)
            .navigationTitle("edit_card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(cardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("confirm_delete_card", isPresented: $showDeleteConfirmation) {
                Button("cancel", role: .cancel) { }
                Button("delete", role: .destructive) {
                    deleteCard()
                }
            } message: {
                Text("delete_card_warning")
            }
        }
    }
    
    private func saveChanges() {
        let trimmedName = cardName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        card.name = trimmedName
        card.type = cardType
        
        HapticManager.shared.impact(style: .medium)
        dismiss()
    }
    
    private func deleteCard() {
        modelContext.delete(card)
        HapticManager.shared.notification(type: .warning)
        dismiss()
    }
}
