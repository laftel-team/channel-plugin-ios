//
//  NewMessageDividerCell.swift
//  CHPlugin
//
//  Created by Haeun Chung on 22/02/2017.
//  Copyright © 2017 ZOYI. All rights reserved.
//

import Reusable
import SnapKit

final class NewMessageDividerCell: BaseTableViewCell, Reusable {
  // MARK: constant
  
  // MARK: properties
  let containerView = UIView().then {
    $0.backgroundColor = CHColors.lightAzure
  }
  
  let titleLabel = UILabel().then {
    $0.font = UIFont.boldSystemFont(ofSize: 13)
    $0.textColor = CHColors.azure
  }
  
  override func initialize() {
    super.initialize()
    self.titleLabel.text = CHAssets.localized("ch.unread_divider")
    
    self.addSubview(self.containerView)
    self.containerView.addSubview(self.titleLabel)
  }
  
  override func setLayouts() {
    super.setLayouts()
    
    self.containerView.snp.makeConstraints { (make) in
      make.edges.equalToSuperview().inset(UIEdgeInsets(top:18, left:0, bottom:0, right:0))
    }
    
    self.titleLabel.snp.makeConstraints { (make) in
      make.centerX.equalToSuperview()
      make.centerY.equalToSuperview()
    }
  }

  class func cellHeight() -> CGFloat {
    return 54
  }
}
