import SwiftUI
import CoreData

struct AuthView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authService: AuthService
    
    @State private var username = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showForgotPassword = false
    
    var body: some View {
        VStack(spacing: Serenity.Layout.standardPadding) {
            Text("Welcome to Serenica")
                .font(Serenity.Typography.screenTitle())
                .padding(.top, 50)
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .frame(height: Serenity.Layout.minimumTapTarget)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(height: Serenity.Layout.minimumTapTarget)
            
            Button(action: handleAuth) {
                Text(isSignUp ? "Sign Up" : "Sign In")
                    .frame(maxWidth: .infinity)
                    .frame(height: Serenity.Layout.minimumTapTarget)
                    .background(Serenity.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(Serenity.Layout.cornerRadius)
            }
            
            Button(action: { isSignUp.toggle() }) {
                Text(isSignUp ? "Already have an account? Sign In"
                             : "Don't have an account? Sign Up")
                    .font(Serenity.Typography.bodyText())
                    .foregroundColor(Serenity.Colors.primary)
            }
            
            if !isSignUp {
                Button("Forgot Password?") {
                    showForgotPassword = true
                }
                .font(Serenity.Typography.bodyText())
                .foregroundColor(Serenity.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(Serenity.Layout.standardPadding)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authService)
        }
    }
    
    private func handleAuth() {
        do {
            if isSignUp {
                try authService.signUp(username: username, password: password)
            } else {
                try authService.signIn(username: username, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

/*
#Preview {
    NavigationView {
        AuthView().withPreviewDependencies()
    }
}

*/
