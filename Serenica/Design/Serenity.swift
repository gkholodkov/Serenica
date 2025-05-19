import SwiftUI

enum Serenity {
    enum Colors {
        /// A simple black accent color in place of the old PrimaryGreen
        static let primary = Color.black
        
        /// A neutral secondary color
        static let secondary = Color.gray
        
        /// A ligh gray color
        static let disabled = Color(hex: "#E0E0E0")
        
        /// White background, matching the mockups
        static let background = Color.white
        
        /// Main text is pure black
        static let textPrimary = Color.black
        
        /// Secondary text (e.g. placeholders, hints) is a lighter gray
        static let textSecondary = Color(UIColor.secondaryLabel)  // #8E8E93
        
        /// Deleteion and cancellation text color
        static let textDanger = Color.red
        
        /// Recording on color
        static let recordingOn = Color.red
        
        /// Divider lines remain the same light gray
        static let divider = Color(hex: "E5E5EA")
        
        /// Chat-specific colors, also toned down
        static let messageBubbleUser = Color(hex: "#E0E0E0")
        static let messageBubbleBot = Color(hex: "#F5F5F5")
        
        /// Calendar specific colors
        static let todayCellColor = Color(red: 241/255, green: 241/255, blue: 241/255)
        static let selectedCellColor = Color(red: 117/255, green: 117/255, blue: 117/255)
        static let overdueEvent = Color.red
    }
    
    enum Typography {
        /// For nav-bar icons like "AddEvent"
        static func screenIcon() -> Font {
            .system(.title, design: .default, weight: .regular)
        }
        /// For nav-bar titles like “Unassigned,” “Today,” “January,” “Completed”
        static func screenTitle() -> Font {
            .system(.title2, design: .default, weight: .bold)  // ~22pt
        }
        
        /// For  titles subtitles like “Week 3"
        static func screenSubtitle() -> Font {
            .system(.title3, design: .default, weight: .regular)  // ~20pt
        }
        
        /// Primary body text (e.g. “Something to be done”)
        static func bodyText() -> Font {
            .system(.body, weight: .regular) // ~17pt
        }
        
        /// Caption text (small, ~12pt)
        static func caption() -> Font {
            .system(.subheadline)
        }
        
        /// For chat message text or other standard content
        static func messageText() -> Font {
            .system(.body)  // ~16pt
        }

        /// Optional subtitle styling if needed
        static func subtitle() -> Font {
            .system(.title3, design: .rounded, weight: .semibold)
        }
    }
    
    enum Layout {
        /// Standard spacing for edges or containers
        static let standardPadding: CGFloat = 16
        
        /// Smaller spacing between close elements
        static let smallPadding: CGFloat = 8
        
        /// Minimal spacing (e.g., tiny separators)
        static let tinyPadding: CGFloat = 4
        
        /// Default corner radius for rounded shapes
        static let cornerRadius: CGFloat = 12
        
        /// Specific corner radius for chat bubbles if used
        static let messageBubbleRadius: CGFloat = 16
        
        /// Minimum tap target size per Apple’s guidelines
        static let minimumTapTarget: CGFloat = 44
        
        /// Typical iOS tab bar height
        static let tabBarHeight: CGFloat = 49
        
        /// Typical iOS navigation bar height
        static let navBarHeight: CGFloat = 44
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit, e.g. #FFF)
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6: // RGB (24-bit, e.g. #FFFFFF)
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8: // ARGB (32-bit, e.g. #FF0000FF)
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
