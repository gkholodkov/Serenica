import SwiftUI

// MARK: - Custom Checkbox View

/// A square checkbox view with a slight corner radius.
/// Displays a filled checkmark when checked.
struct CheckboxView: View {
    let isChecked: Bool
    private let size: CGFloat = 20
    
    var body: some View {
        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundColor(isChecked ? Serenity.Colors.primary : .gray)
            .cornerRadius(2)
            .accessibilityHidden(true)
    }
}


#Preview {
    CheckboxView(isChecked: false)
}
