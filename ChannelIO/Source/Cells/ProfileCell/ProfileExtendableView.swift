//
//  ProfileExtendableView.swift
//  ChannelIO
//
//  Created by R3alFr3e on 4/11/18.
//  Copyright © 2018 ZOYI. All rights reserved.
//

import UIKit

class ProfileExtendableView: BaseView {
  struct Metric {
    static let footerLeading = 12.f
    static let footerTrailing = 12.f
    static let footerBottom = 12.f
    static let topMargin = 10.f
    static let itemHeight = 80.f
  }
  
  var items: [ProfileContentProtocol] = []
  var footerLabel = UILabel().then {
    $0.numberOfLines = 0

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = CHAssets.localized("ch.agreement").guessLanguage() == "日本語" ?
      .byCharWrapping : .byWordWrapping

    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 11),
      .foregroundColor: CHColors.blueyGrey,
      .paragraphStyle: paragraph
    ]
    
    let tagAttributes: [StringTagType: [NSAttributedString.Key: Any]] = [
      .bold:[
        .font: UIFont.boldSystemFont(ofSize: 11),
        .foregroundColor: CHColors.blueyGrey,
        .paragraphStyle: paragraph
      ]
    ]
    
    $0.attributedText = CHAssets.localized(
      "ch.agreement",
      attributes: attributes,
      tagAttributes: tagAttributes)
  }
  
  var shouldBecomeFirstResponder = false
  
  override func initialize() {
    super.initialize()
    self.addSubview(self.footerLabel)
    
    _ = self.footerLabel.signalForClick().subscribe { _ in
      UserChatActions.openAgreement()
    }
    
    self.layer.borderColor = CHColors.dark10.cgColor
    self.layer.borderWidth = 1.f
    self.layer.cornerRadius = 6.f
    
    self.layer.shadowColor = CHColors.dark.cgColor
    self.layer.shadowOpacity = 0.2
    self.layer.shadowOffset = CGSize(width: 0, height: 2)
    self.layer.shadowRadius = 2
    self.backgroundColor = CHColors.white
  }
  
  override func setLayouts() {
    super.setLayouts()
    
    self.footerLabel.snp.makeConstraints { (make) in
      make.bottom.equalToSuperview().inset(Metric.footerBottom)
      make.left.equalToSuperview().inset(Metric.footerLeading)
      make.right.equalToSuperview().inset(Metric.footerTrailing)
    }
  }
  
  func configure(model: MessageCellModelType, presenter: ChatManager? = nil, redraw: Bool = false) {
    if redraw {
      presenter?.shouldRedrawProfileBot = false
      self.drawViews(model: model, presenter: presenter)
    } 
  }
  
  func drawViews(model: MessageCellModelType, presenter: ChatManager? = nil) {
    for item in self.items {
      if item.didFirstResponder {
        self.shouldBecomeFirstResponder = true
        break
      }
    }
    
    //NOTE: this can be optimized, do not draw everything again if not necessary
    self.items.forEach { (item) in
      item.view.removeFromSuperview()
    }
    self.items = []
    var lastView: UIView?
    
    for (index, item) in model.profileItems.enumerated() {
      if item.value != nil {
        let completionView = ProfileCompletionView()
        completionView.configure(model: model, index: index, presenter: presenter)
        self.addSubview(completionView)
        self.items.append(completionView)
        
        completionView.snp.makeConstraints({ (make) in
          if let lview = lastView {
            make.top.equalTo(lview.snp.bottom)
          } else {
            make.top.equalToSuperview().inset(Metric.topMargin)
          }
          make.height.equalTo(Metric.itemHeight)
          make.leading.equalToSuperview()
          make.trailing.equalToSuperview()
          if index == 3 {
            make.bottom.equalToSuperview()
          }
        })
        lastView = completionView
      } else {
        var itemView: ProfileContentProtocol?
        if item.fieldType == .mobileNumber {
          let phoneView = ProfilePhoneView()
          phoneView.configure(model: model, index:index, presenter: presenter)
          self.addSubview(phoneView)
          self.items.append(phoneView)
          itemView = phoneView
        } else {
          let textView = ProfileTextView()
          textView.fieldType = item.fieldType
          textView.configure(model: model, index: index, presenter: presenter)
          self.addSubview(textView)
          self.items.append(textView)
          itemView = textView
        }
        
        if self.shouldBecomeFirstResponder {
          itemView?.firstResponder.becomeFirstResponder()
        }
        
        itemView?.view.snp.makeConstraints({ (make) in
          if let lview = lastView {
            make.top.equalTo(lview.snp.bottom)
          } else {
            make.top.equalToSuperview().inset(Metric.topMargin)
          }
          make.height.equalTo(Metric.itemHeight)
          make.leading.equalToSuperview()
          make.trailing.equalToSuperview()
          if index == 3 {
            make.bottom.equalToSuperview()
          }
        })
        break
      }
    }
    
    self.footerLabel.isHidden = self.items.count != 1
  }
  
  class func viewHeight(fit width: CGFloat, model: MessageCellModelType) -> CGFloat {
    var height = 0.f
    height += Metric.topMargin //top margin
    height += CGFloat(model.currentIndex + 1) * Metric.itemHeight
    if model.currentIndex == 0 {
      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      paragraph.lineBreakMode = .byCharWrapping

      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 11),
        .foregroundColor: CHColors.blueyGrey,
        .paragraphStyle: paragraph
      ]
      
      let tagAttributes: [StringTagType: [NSAttributedString.Key: Any]] = [
        StringTagType.bold:[
          .font: UIFont.boldSystemFont(ofSize: 11),
          .foregroundColor: CHColors.blueyGrey,
          .paragraphStyle: paragraph
        ]
      ]
      
      let text = CHAssets.localized(
        "ch.agreement",
        attributes: attributes,
        tagAttributes: tagAttributes)
      
      height += text.height(fits: width - Metric.footerLeading - Metric.footerTrailing)
      height += Metric.footerBottom
    }

    return height
  }
}
