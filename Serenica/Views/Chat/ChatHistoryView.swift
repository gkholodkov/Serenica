import SwiftUI

struct ChatHistoryView: UIViewControllerRepresentable {
    @Binding var messages: [Message]
    @Binding var scrollToBottomTrigger: Bool // Toggle this (e.g. set to true then false) when you want to force a scroll-to-bottom

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
        uiViewController.reloadData()
        if scrollToBottomTrigger {
            DispatchQueue.main.async {
                uiViewController.scrollToBottom(animated: true)
            }
        }
    }

    class Coordinator: NSObject, ChatViewControllerDelegate {
        var parent: ChatHistoryView
        init(_ parent: ChatHistoryView) { self.parent = parent }
    }
}
