//
//  TextActionView.swift
//  CHPlugin
//
//  Created by Haeun Chung on 16/02/2017.
//  Copyright © 2017 ZOYI. All rights reserved.
//

import Foundation
import RxSwift
import SnapKit

class TextActionView: DialogActionView {
  //MARK: Constants
  
  //MARK: Properties
  let submitSubject = PublishSubject<Any?>()
  let confirmButton = UIButton().then {
    $0.setTitle(CHAssets.localized("ch.name_verification.button"), for: UIControlState.normal)
    $0.setTitleColor(CHColors.dark, for: UIControlState.normal)
    $0.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
    $0.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
  }
  
  let textField = UITextField().then {
    $0.font = UIFont.systemFont(ofSize: 18)
    $0.textColor = CHColors.dark
    $0.placeholder = CHAssets.localized("ch.name_verification.placeholder")
  }
  
  let disposeBeg = DisposeBag()
  //MARK: Init
  
  override func initialize() {
    super.initialize()
    self.translatesAutoresizingMaskIntoConstraints = false
    
    self.addSubview(self.confirmButton)
    self.addSubview(self.textField)

    self.confirmButton.signalForClick()
      .subscribe(onNext: { [weak self] _ in
      self?.submitSubject.onNext(self?.textField.text)
    }).disposed(by: self.disposeBeg)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    self.textField.snp.makeConstraints { (make) in
      make.leading.equalToSuperview().inset(10)
      make.top.equalToSuperview()
      make.bottom.equalToSuperview()
    }
    
    self.confirmButton.snp.makeConstraints { [weak self] (make) in
      make.left.equalTo((self?.textField.snp.right)!)
      make.width.equalTo(75)
      make.trailing.equalToSuperview()
      make.top.equalToSuperview()
      make.bottom.equalToSuperview()
    }
  }
  
  //MARK: UserActionView Protocol
  
  override func signalForAction() -> PublishSubject<Any?> {
    return submitSubject
  }
  
}