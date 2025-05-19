import UIKit
import SwiftUI

protocol ChatViewControllerDelegate: AnyObject {}

class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    weak var delegate: ChatViewControllerDelegate?

    var messages: [Message] = []

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let scrollButton = UIButton(type: .system)

    private var groupedMessages: [(section: String, messages: [Message])] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Table setup
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .interactive
        tableView.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")
        view.addSubview(tableView)

        // Floating button
        scrollButton.setImage(UIImage(systemName: "arrow.down.circle"), for: .normal)
        scrollButton.tintColor = .black
        scrollButton.layer.shadowRadius = 4
        scrollButton.layer.shadowOpacity = 0.5
        scrollButton.layer.cornerRadius = 28
        scrollButton.clipsToBounds = true
        scrollButton.addTarget(self, action: #selector(scrollButtonTapped), for: .touchUpInside)
        scrollButton.isHidden = true
        view.addSubview(scrollButton)
        
        
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds

        let size: CGFloat = 56
        let padding: CGFloat = 16
        scrollButton.frame = CGRect(
            x: view.bounds.width - size - padding,
            y: view.bounds.height - size,
            width: size, height: size
        )
    }

    func reloadData() {
        groupedMessages = Self.groupMessagesByDay(messages)
        tableView.reloadData()
        updateScrollButtonVisibility()
    }

    func scrollToBottom(animated: Bool) {
        guard groupedMessages.count > 0 else { return }
        let lastSection = groupedMessages.count - 1
        let lastRow = groupedMessages[lastSection].messages.count - 1
        let indexPath = IndexPath(row: lastRow, section: lastSection)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
        updateScrollButtonVisibility()
    }

    @objc private func scrollButtonTapped() {
        if tableView.isDecelerating {
            tableView.setContentOffset(tableView.contentOffset, animated: false)
        }
        scrollToBottom(animated: true)
    }

    // MARK: - Scroll Button Show/Hide

    func updateScrollButtonVisibility() {
        // Show button if not at the very bottom
        guard tableView.numberOfSections > 0 else {
            scrollButton.isHidden = true
            return
        }
        let lastSection = tableView.numberOfSections - 1
        let lastRow = tableView.numberOfRows(inSection: lastSection) - 1
        guard lastSection >= 0 && lastRow >= 0 else {
            scrollButton.isHidden = true
            return
        }
        let lastIndexPath = IndexPath(row: lastRow, section: lastSection)
        if let visibleRows = tableView.indexPathsForVisibleRows, visibleRows.contains(lastIndexPath) {
            scrollButton.isHidden = true
        } else {
            scrollButton.isHidden = false
        }
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        groupedMessages.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groupedMessages[section].messages.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        groupedMessages[section].section
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.text = groupedMessages[section].section
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        
        // Custom background view
        let bgView = UIView()
        bgView.backgroundColor = UIColor.systemGray5.withAlphaComponent(0.85) // light, neutral, adaptive
        bgView.layer.cornerRadius = 14
        bgView.clipsToBounds = true

        // Add label to background view
        bgView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bgView.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bgView.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: bgView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: bgView.trailingAnchor, constant: -16),
        ])

        // Center the bgView horizontally (and give it a fixed width)
        let container = UIView()
        container.addSubview(bgView)
        bgView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bgView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bgView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            bgView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            bgView.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
        ])

        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        44
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = groupedMessages[indexPath.section].messages[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
        cell.configure(with: msg)
        return cell
    }

    // MARK: - Scroll View Delegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateScrollButtonVisibility()
    }

    // MARK: - Grouping Logic

    static func groupMessagesByDay(_ messages: [Message]) -> [(section: String, messages: [Message])] {
        guard !messages.isEmpty else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: messages) { msg in
            if calendar.isDateInToday(msg.timestamp) {
                return "Today"
            } else if calendar.isDateInYesterday(msg.timestamp) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: msg.timestamp)
            }
        }
        .sorted { lhs, rhs in
            guard let lhsDate = lhs.value.first?.timestamp, let rhsDate = rhs.value.first?.timestamp else { return false }
            return lhsDate < rhsDate
        }
        return grouped.map { (section: $0.key, messages: $0.value) }
    }
}
