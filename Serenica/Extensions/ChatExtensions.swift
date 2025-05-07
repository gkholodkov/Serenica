import Foundation
import UIKit

extension String {
  func height(constrainedTo width: CGFloat,
              font: UIFont,
              verticalPadding: CGFloat) -> CGFloat {
    let maxSize = CGSize(width: width, height: .greatestFiniteMagnitude)
    let rect = (self as NSString).boundingRect(
      with: maxSize,
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: font],
      context: nil
    )
    return ceil(rect.height) + verticalPadding
  }
}
