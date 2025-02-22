import SwiftUI

struct DatePickerSheet: View {
    @Binding var date: Date
    var minimumDate: Date?
    var maximumDate: Date?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            WheelDatePicker(date: $date, minimumDate: minimumDate, maximumDate: maximumDate)
            Button("Done") {
                dismiss()
            }
            .padding()
        }
    }
}

struct WheelDatePicker: UIViewRepresentable {
    @Binding var date: Date
    var minimumDate: Date?
    var maximumDate: Date?
    
    func makeUIView(context: Context) -> UIDatePicker {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime // Show both date and time
        datePicker.preferredDatePickerStyle = .wheels // Use the wheel style
        datePicker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged), for: .valueChanged)
        return datePicker
    }
    
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.date = date
        uiView.minimumDate = minimumDate
        uiView.maximumDate = maximumDate
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: WheelDatePicker
        
        init(_ parent: WheelDatePicker) {
            self.parent = parent
        }
        
        @objc func dateChanged(_ sender: UIDatePicker) {
            parent.date = sender.date
        }
    }
}

#Preview {
    DatePickerSheet(date: .constant(Date()))
}
