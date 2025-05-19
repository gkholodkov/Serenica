import SwiftUI

struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var focusTrigger: Bool // just a trigger, not a focus state
    let maxLines: Int
    let font: UIFont
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = font
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 2, bottom: 8, right: 2)
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.returnKeyType = .default
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = font
        let maxHeight = font.lineHeight * CGFloat(maxLines) + 16
        let size = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: .greatestFiniteMagnitude))
        let newHeight = min(size.height, maxHeight)
        if height != newHeight {
            DispatchQueue.main.async {
                height = newHeight
            }
        }
        uiView.isScrollEnabled = size.height > maxHeight

        // Only focus if triggered
        if focusTrigger && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
            DispatchQueue.main.async {
                self.focusTrigger = false // reset trigger
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView

        init(_ parent: GrowingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            if parent.text != textView.text {
                parent.text = textView.text
            }
        }
    }
}
