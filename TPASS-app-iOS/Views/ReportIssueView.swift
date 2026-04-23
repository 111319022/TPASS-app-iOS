import SwiftUI

@MainActor
struct ReportIssueView: View {
    @EnvironmentObject var themeManager: ThemeManager

    @FocusState private var focusedField: Field?
    @AppStorage("issueReportContactEmail") private var email = ""
    @State private var content = ""
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private enum Field {
        case email
        case content
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("issueReport")
                        .font(.title2.bold())
                        .foregroundStyle(themeManager.primaryTextColor)
                    Text("issueReportSubtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text("issueReportEmail")
                        } icon: {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.blue)
                        }
                        .font(.headline)

                        TextField("issueReportEmailPlaceholder", text: $email)
                            .focused($focusedField, equals: .email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(themeManager.cardBackgroundColor.opacity(0.85))
                            )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text("issueReportDescription")
                        } icon: {
                            Image(systemName: "text.bubble.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.headline)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(themeManager.cardBackgroundColor.opacity(0.85))

                            TextEditor(text: $content)
                                .focused($focusedField, equals: .content)
                                .frame(minHeight: 180)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)

                            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("issueReportDescriptionPlaceholder")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 22)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(themeManager.backgroundColor.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(themeManager.primaryTextColor.opacity(0.08), lineWidth: 1)
                        )
                )

                Button {
                    submitReport()
                } label: {
                    HStack(spacing: 10) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }

                        Text(isSubmitting ? "issueReportSubmitting" : "issueReportSubmit")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.78)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(isSubmitting || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(isSubmitting || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.65 : 1)

            }
            .padding(20)
        }
        .background {
            Rectangle()
                .fill(themeManager.backgroundColor)
                .ignoresSafeArea()
        }
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("issueReport")
        .alert(alertTitle, isPresented: $showAlert) {
            Button("issueReportAlertConfirm", role: .cancel) {}
        } message: {
            Text(verbatim: alertMessage)
        }
    }

    private func submitReport() {
        guard !isSubmitting else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        email = trimmedEmail
        isSubmitting = true

        Task {
            do {
                try await IssueReportService.shared.submitReport(content: content, email: trimmedEmail)
                await MainActor.run {
                    isSubmitting = false
                    content = ""
                    alertTitle = String(localized: "issueReportSuccessTitle")
                    alertMessage = String(localized: "issueReportSuccessMessage")
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    alertTitle = String(localized: "issueReportFailureTitle")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

}
