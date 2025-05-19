import UIKit
import SwiftUI

class MessageCell: UITableViewCell {
    private var hostController: UIHostingController<MessageBubble>?

    override func prepareForReuse() {
        super.prepareForReuse()
        hostController?.view.removeFromSuperview()
        hostController = nil
    }

    func configure(with message: Message) {
        let bubble = MessageBubble(message: message)
        if let hostController = hostController {
            hostController.rootView = bubble
            hostController.view.setNeedsLayout()
        } else {
            let hc = UIHostingController(rootView: bubble)
            hc.view.backgroundColor = .clear
            hc.view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(hc.view)
            NSLayoutConstraint.activate([
                hc.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hc.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hc.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hc.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            hostController = hc
        }
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
    }
}
