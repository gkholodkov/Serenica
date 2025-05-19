import SwiftUI

struct PermissionRow: View {
    let icon: String
    let label: String
    @Binding var status: PermissionStatus
    let onRequest: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(label)
            Spacer()
            Toggle("", isOn: Binding(
                get: { status == .granted },
                set: { newValue in
                    if newValue && status != .granted {
                        onRequest()
                    } else if !newValue && status == .granted {
                        onSettings()
                    }
                }
            ))
            .labelsHidden()
            .disabled(status == .restricted)
        }
    }
}
