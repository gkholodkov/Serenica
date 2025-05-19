import SwiftUI

struct ChatViewRepresentable: UIViewControllerRepresentable {
    @Binding var messages: [Message] // Replace with your Message model
    let scrollToBottomTrigger: Bool // Toggle this to programmatically scroll to bottom

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> ChatViewController {
        let vc = ChatViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ChatViewController, context: Context) {
        uiViewController.messages = messages
        if scrollToBottomTrigger {
            uiViewController.scrollToBottom(animated: true)
        }
        uiViewController.reloadData()
    }

    class Coordinator: NSObject, ChatViewControllerDelegate {
        var parent: ChatViewRepresentable

        init(_ parent: ChatViewRepresentable) {
            self.parent = parent
        }
    }
}
