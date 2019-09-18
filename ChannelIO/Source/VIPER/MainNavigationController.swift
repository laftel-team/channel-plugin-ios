//
//  MainNavigationController.swift
//  CHPlugin
//
//  Created by 이수완 on 2017. 1. 14..
//  Copyright © 2017년 ZOYI. All rights reserved.
//

import UIKit
import ReSwift
import RxSwift
import RxCocoa

protocol CHNavigationDelegate: class {
  func willPopViewController(willShow controller:UIViewController)
  //func willPushViewController()
}

class MainNavigationController: BaseNavigationController {

  // MARK: Properties
  weak var chDelegate: CHNavigationDelegate? = nil
  var statusBarStyle = UIStatusBarStyle.default
  var isPushingViewController = false
  
  var currentBgColor: UIColor?
  var currentGradientColor: UIColor?
  
  let disposeBag = DisposeBag()
  
  struct StatusBar {
    static var isHidden = false
    static var style = UIStatusBarStyle.default
  }
  
  var useDefault = false {
    didSet {
      if useDefault {
        self.navigationBar.barTintColor = nil
        self.navigationBar.titleTextAttributes =  [.foregroundColor: mainStore.state.plugin.textUIColor]
        self.navigationBar.isTranslucent = false
        self.statusBarStyle = .lightContent
        self.setNeedsStatusBarAppearanceUpdate()
      }
    }
  }
  
  // MARK: View Life Cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    self.delegate = self
    self.interactivePopGestureRecognizer?.delegate = self
    self.navigationBar.isTranslucent = false
    self.navigationBar.barStyle = .black

    if #available(iOS 13, *) {
      self.presentationController?.delegate = self
    }
    
    self.navigationBar.rx.observeWeakly(CGRect.self, "frame")
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { [weak self] (frame) in
        self?.navigationBar.setGradientBackground(
          colors: mainStore.state.plugin.gradientColors,
          startPoint: .left,
          endPoint: .right
        )
      }).disposed(by: self.disposeBag)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    //legacy support
    StatusBar.isHidden = UIApplication.shared.isStatusBarHidden
    StatusBar.style = UIApplication.shared.statusBarStyle
    UIApplication.shared.isStatusBarHidden = false
    
    mainStore.subscribe(self) {
      $0.select { (state: AppState) in
        state.plugin
      }.skipRepeats { $0 == $1 }
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    //legacy support
    UIApplication.shared.isStatusBarHidden = StatusBar.isHidden
    UIApplication.shared.statusBarStyle = StatusBar.style
    mainStore.unsubscribe(self)
  }

  override var prefersStatusBarHidden: Bool {
    return false
  }
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return self.statusBarStyle
  }
  
  override var shouldAutorotate: Bool {
    return false
  }
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return UIInterfaceOrientationMask.portrait
  }
}

// MARK: - StoreSubscriber

extension MainNavigationController: StoreSubscriber {
  func newState(state: CHPlugin) {
    if !self.useDefault {
      // Bar Color
//      self.navigationBar.barTintColor = UIColor(state.color)

      self.navigationBar.setGradientBackground(
        colors: state.gradientColors,
        startPoint: .left,
        endPoint: .right
      )

      self.navigationBar.setValue(true, forKey: "hidesShadow")
      self.navigationBar.tintColor = state.textUIColor
      
      // Title
      if self.title == nil || self.title == "" {
        self.navigationBar.topItem?.title = state.name
      }
      
      // Title Color
      self.navigationBar.titleTextAttributes = [.foregroundColor: state.textUIColor]
      
      // Status bar color
      self.statusBarStyle = state.textColor == "white" ? .lightContent : .default
      //legacy support
      UIApplication.shared.statusBarStyle = self.statusBarStyle
      self.setNeedsStatusBarAppearanceUpdate()
    }
  }
}

extension MainNavigationController: UIGestureRecognizerDelegate {
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard gestureRecognizer is UIScreenEdgePanGestureRecognizer else { return true }
    return viewControllers.count > 1 && !isPushingViewController
  }
  
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
  
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return false
  }
}

extension MainNavigationController : UINavigationControllerDelegate {
  func navigationController(
    _ navigationController: UINavigationController,
    didShow viewController: UIViewController, animated: Bool) {
    isPushingViewController = false
  }
  
  func navigationController(
    _ navigationController: UINavigationController,
    willShow viewController: UIViewController,
    animated: Bool) {
    if let coordinator = navigationController.topViewController?.transitionCoordinator {
      coordinator.notifyWhenInteractionEnds({ (context) in
        if !context.isCancelled {
          self.chDelegate?.willPopViewController(willShow: viewController)
        }
      })
    }
  }
}

@available(iOS 13, *)
extension MainNavigationController : UIAdaptivePresentationControllerDelegate {
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    ChannelIO.didDismiss()
  }
  
  func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
    ChannelIO.delegate?.willHideMessenger?()
  }
}
