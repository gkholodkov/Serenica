import SwiftUI
import CoreData

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authService: AuthService
    
    @State private var username = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: Serenity.Layout.standardPadding) {
                Text("Reset Password")
                    .font(Serenity.Typography.screenTitle())
                    .padding(.top, 50)
                
                Text("Enter your username and new password")
                    .font(Serenity.Typography.bodyText())
                    .multilineTextAlignment(.center)
                    .foregroundColor(Serenity.Colors.textSecondary)
                    .padding(.horizontal)
                
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disabled(isProcessing)
                    .frame(height: Serenity.Layout.minimumTapTarget)
                
                SecureField("New Password", text: $newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isProcessing)
                    .frame(height: Serenity.Layout.minimumTapTarget)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isProcessing)
                    .frame(height: Serenity.Layout.minimumTapTarget)
                
                Button(action: resetPassword) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Reset Password")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: Serenity.Layout.minimumTapTarget)
                .background(isFormInvalid ? Serenity.Colors.secondary : Serenity.Colors.primary)
                .foregroundColor(.white)
                .cornerRadius(Serenity.Layout.cornerRadius)
                .disabled(isFormInvalid)
                
                Spacer()
            }
            .padding(Serenity.Layout.standardPadding)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Your password has been reset successfully.")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Serenity.Colors.primary)
                }
            }
        }
    }
    
    private var isFormInvalid: Bool {
        username.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty ||
        newPassword != confirmPassword ||
        isProcessing
    }
    
    private func resetPassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match"
            showError = true
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                try await authService.resetPassword(username: username, newPassword: newPassword)
                await MainActor.run {
                    isProcessing = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView().withPreviewDependencies()
}

