import SwiftUI

struct WheelDatePicker: UIViewRepresentable {
    @Binding var date: Date
    var dateOnly: Bool = false
    var minimumDate: Date?
    var maximumDate: Date?
    
    func makeUIView(context: Context) -> UIDatePicker {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = !dateOnly ? .dateAndTime : .date
        datePicker.preferredDatePickerStyle = .wheels
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
        init(_ parent: WheelDatePicker) { self.parent = parent }
        @objc func dateChanged(_ sender: UIDatePicker) { parent.date = sender.date }
    }
}

#Preview {
    WheelDatePicker(date: .constant(Date()))
}
