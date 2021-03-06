//
//  MarkdownLinkElement.swift
//  Pods
//
//  Created by Ivan Bruel on 18/07/16.
//
//

import UIKit

/// The base to all Link parsing elements.
protocol MarkdownLinkElement: MarkdownElement, MarkdownStyle {
  
  func formatText(_ attributedString: NSMutableAttributedString, range: NSRange, link: String)
  func addAttributes(_ attributedString: NSMutableAttributedString, range: NSRange, link: String)
}
