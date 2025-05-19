import SwiftUI

struct CustomAlert: View {
    var title: String
    var message: String
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(Serenity.Typography.screenSubtitle())
                .foregroundColor(Serenity.Colors.textPrimary)
                .padding(.top, 20)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)

            Text(message)
                .font(Serenity.Typography.bodyText())
                .foregroundColor(Serenity.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)

            Divider()
                .background(Serenity.Colors.divider)

            HStack(spacing: 0) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                Divider()
                    .background(Serenity.Colors.divider)
                Button(action: onConfirm) {
                    Text("Reset")
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textDanger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .background(Serenity.Colors.background)
        .cornerRadius(Serenity.Layout.cornerRadius)
        .shadow(radius: 24)
        .padding(.horizontal, 32)
    }
}
