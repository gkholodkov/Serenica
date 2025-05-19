import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var messageService: MessageService
    
    @StateObject private var permissionsVM = PermissionsViewModel()
    @State private var showSettingsAlert = false
    @State private var pendingSettingsType: String? = nil
    
    @State private var showResetDialog = false
    @State private var isResetPressed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Serenity.Layout.standardPadding) {
                // --- Profile Summary / Avatar ---
                Group {
                    HStack(spacing: Serenity.Layout.standardPadding) {
                        Circle()
                            .fill(Serenity.Colors.disabled)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Serenity.Colors.secondary)
                            )
                        VStack(alignment: .leading, spacing: Serenity.Layout.tinyPadding) {
                            Text(authService.currentUser?.username ?? "User")
                                .font(Serenity.Typography.screenTitle())
                                .foregroundColor(Serenity.Colors.textPrimary)
                            Text("Profile Details")
                                .font(Serenity.Typography.caption())
                                .foregroundColor(Serenity.Colors.textSecondary)
                        }
                    }
                    .padding(.vertical, Serenity.Layout.standardPadding)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Serenity.Colors.background)
                .cornerRadius(Serenity.Layout.cornerRadius)

                Divider().background(Serenity.Colors.divider)
                
                // --- App Permissions Section ---
                Group {
                    Text("App Permissions")
                        .font(.headline)
                        .padding(.top, Serenity.Layout.standardPadding)
                                    
                    PermissionRow(
                        icon: "bell.badge",
                        label: "Notifications",
                        status: $permissionsVM.notificationStatus,
                        onRequest: {
                            permissionsVM.requestNotificationPermission { granted in
                                if !granted { showSettingsDialog(for: "Notifications") }
                            }
                        },
                        onSettings: {
                            showSettingsDialog(for: "Notifications")
                        }
                    )
                                    
                    PermissionRow(
                        icon: "mic.fill",
                        label: "Microphone",
                        status: $permissionsVM.micStatus,
                        onRequest: {
                            permissionsVM.requestMicPermission { granted in
                                if !granted { showSettingsDialog(for: "Microphone") }
                            }
                        },
                        onSettings: {
                            showSettingsDialog(for: "Microphone")
                        }
                    )
                                    
                    PermissionRow(
                        icon: "waveform",
                        label: "Speech Recognition",
                        status: $permissionsVM.speechStatus,
                        onRequest: {
                            permissionsVM.requestSpeechPermission { granted in
                                if !granted { showSettingsDialog(for: "Speech Recognition") }
                            }
                        },
                        onSettings: {
                            showSettingsDialog(for: "Speech Recognition")
                        }
                    )
                }
                .alert(isPresented: $showSettingsAlert) {
                    Alert(
                        title: Text("Change Permissions"),
                        message: Text("To change \(pendingSettingsType ?? "this") permission, go to iOS Settings."),
                        primaryButton: .default(Text("Open Settings")) {
                            permissionsVM.openSettings()
                        },
                        secondaryButton: .cancel()
                    )
                }
                .onAppear {
                    permissionsVM.refreshStatuses()
                }

                // --- Main Actions ---
                VStack(spacing: Serenity.Layout.smallPadding) {
                    Button(action: {
                        showResetDialog = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Conversation")
                        }
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isResetPressed ? Serenity.Colors.disabled.opacity(0.9) : Serenity.Colors.disabled.opacity(0.6))
                        .cornerRadius(Serenity.Layout.cornerRadius)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in isResetPressed = true }
                            .onEnded { _ in isResetPressed = false }
                    )
                    .confirmationDialog(
                        "",
                        isPresented: $showResetDialog,
                        titleVisibility: .hidden
                    ) {
                        Button("Reset", role: .destructive) {
                            messageService.clearMessages()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will remove the entire message history, all facts, and all extracted emotions. This action cannot be undone.")
                            .font(Serenity.Typography.bodyText())
                    }

                    Button(role: .destructive) {
                        authService.signOut()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textDanger)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Serenity.Colors.disabled)
                        .cornerRadius(Serenity.Layout.cornerRadius)
                    }
                }
                .padding(.top, Serenity.Layout.standardPadding)

                // --- Placeholder for future sections ---
                Group {
                    // Future sections
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Serenity.Layout.standardPadding)
            .padding(.vertical, Serenity.Layout.standardPadding)
            .background(Serenity.Colors.background)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(Serenity.Colors.background.edgesIgnoringSafeArea(.all))
    }
    
    func showSettingsDialog(for type: String) {
        pendingSettingsType = type
        showSettingsAlert = true
    }
}
