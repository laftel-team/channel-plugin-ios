//
//  ChatManager.swift
//  CHPlugin
//
//  Created by Haeun Chung on 12/12/2017.
//  Copyright © 2017 ZOYI. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

enum ChatElement {
  case message(obj: CHMessage?)
  case manager(obj: CHManager?)
  case session(obj: CHSession?)
  case chat(obj: CHUserChat?)
  case typing(obj: [CHEntity]?, animated: Bool)
}

enum ChatState {
  case idle
  case infoNotLoaded
  case infoLoading
  case infoLoaded
  case chatLoading
  case chatLoaded
  case chatNotLoaded
  case chatJoining
  case waitingSocket
  case messageLoading
  case messageLoaded
  case messageNotLoaded
  case chatReady
}

protocol ChatDelegate : class {
  func updateFor(element: ChatElement)
}

class ChatManager {
  var chatId = ""
  var chatType = ""
  var chat: CHUserChat? = nil {
    didSet {
      if let chat = self.chat {
        self.chatId = chat.id
        self.chatType = "UserChat"
      }
    }
  }
  
  var didFetchInfo = false
  var didChatLoaded = false
  var state: ChatState = .idle
  
  let disposeBag = DisposeBag()

  fileprivate var typingPersons = [CHEntity]()
  fileprivate var timeStorage = [String: Timer]()
  fileprivate var animateTyping = false
  
  var typers: [CHEntity] {
    get {
      return self.typingPersons
    }
  }
  
  weak var delegate: ChatDelegate? = nil
  
  deinit {
    dlog("Destroyed chatManager")
  }
  
  init(id: String?, type: String = "UserChat"){
    self.chatId = id ?? ""
    self.chatType = type
    self.chat = userChatSelector(
      state: mainStore.state,
      userChatId: id)
    
    self.observeSocketEvents()
  }
  
  fileprivate func observeSocketEvents() {
    self.observeMessageEvents()
    self.observeChatEvents()
    self.observeSessionEvents()
    self.observeTypingEvents()
    self.observeAppState()
  }
  
  fileprivate func observeAppState() {
    NotificationCenter.default
      .rx.notification(Notification.Name.UIApplicationWillEnterForeground)
      .observeOn(MainScheduler.instance)
      .subscribe { [weak self] _ in
        if self?.chatId == "" {
          self?.didFetchInfo = false
        }
        self?.didChatLoaded = false
      }.disposed(by: self.disposeBag)
  }
  
  fileprivate func observeMessageEvents() {
    WsService.shared.mOnCreate()
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { [weak self] (message) in
        guard let s = self else { return }
        
        let typing = CHTypingEntity.transform(from: message)
        if let index = s.getTypingIndex(of: typing) {
          let person = s.typingPersons.remove(at: index)
          s.removeTimer(with: person)
          s.delegate?.updateFor(element: .typing(obj: self?.typingPersons, animated: s.animateTyping))
        }
        
        s.delegate?.updateFor(element: .message(obj: message))
      }).disposed(by: self.disposeBag)
  }
  
  fileprivate func observeChatEvents() { }
  fileprivate func observeSessionEvents() { }
  
  fileprivate func observeTypingEvents() {
    WsService.shared.typingSubject
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { [weak self] (typingEntity) in
        guard let s = self else { return }
        if typingEntity.action == "stop" {
          if let index = s.getTypingIndex(of: typingEntity) {
            let person = s.typingPersons.remove(at: index)
            s.removeTimer(with: person)
          }
        }
        else if typingEntity.action == "start" {
          if let manager = personSelector(
            state: mainStore.state,
            personType: typingEntity.personType ?? "",
            personId: typingEntity.personId) as? CHManager {
            if s.getTypingIndex(of: typingEntity) == nil {
              s.typingPersons.append(manager)
            }
            s.addTimer(with: manager, delay: 15)
          }
        }
        //reload row not section only if visible
        s.delegate?.updateFor(element: .typing(obj: s.typingPersons, animated: s.animateTyping))
      }).disposed(by: self.disposeBag)
  }
}

// MARK: live typing

extension ChatManager {
  public func sendTyping(isStop: Bool) {
    WsService.shared.sendTyping(
      chat: self.chat,
      isStop: isStop
    )
  }
  
  fileprivate func addTimer(with person: CHEntity, delay: TimeInterval) {
    let timer = Timer.scheduledTimer(
      timeInterval: delay,
      target: self,
      selector: #selector(self.expired(_:)),
      userInfo: [person],
      repeats: false
    )
    
    if let t = self.timeStorage[person.key] {
      t.invalidate()
    }
    
    self.timeStorage[person.key] = timer
  }
  
  fileprivate func removeTimer(with person: CHEntity?) {
    guard let person = person else { return }
    if let t = self.timeStorage.removeValue(forKey: person.key) {
      t.invalidate()
    }
  }
  
  public func reset() {
    self.timeStorage.forEach { (k, t) in
      t.invalidate()
    }
    self.typingPersons.removeAll()
    self.timeStorage.removeAll()
  }
  
  @objc fileprivate func expired(_ timer: Timer) {
    guard let params = timer.userInfo as? [Any] else { return }
    guard let person = params[0] as? CHEntity else { return }
    
    timer.invalidate()
    if let index = self.typingPersons.index(where: { (p) in
      return p.id == person.id && p.kind == person.kind
    }) {
      self.typingPersons.remove(at: index)
      self.timeStorage.removeValue(forKey: person.key)
      self.delegate?.updateFor(element: .typing(obj: nil, animated: self.animateTyping))
    }
  }
  
  fileprivate func getTypingIndex(of typingEntity: CHTypingEntity) -> Int? {
    return self.typingPersons.index(where: {
      $0.id == typingEntity.personId && $0.kind == typingEntity.personType
    })
  }
}

extension ChatManager {
  func isChatReady() -> Bool {
    return self.state == .chatReady
  }
  
  func isNewUserChat() -> Bool {
    return self.chatId == ""
  }
  
  func needToFetchInfo() -> Bool {
    return !self.didFetchInfo && self.chatId == "" && self.state != .infoLoading
  }
  
  func needToFetchChat() -> Bool {
    return !self.didChatLoaded && self.chatId != "" && self.state != .chatLoading
  }
  
  func isChatLoading() -> Bool {
    return self.state == .chatLoading
  }
  
  func isMessageLoading() -> Bool {
    return self.state == .messageLoading
  }
}

// MARK: APIs

extension ChatManager {
  //NOTE: not considered simultaneous calling of difference fetching functions
  func fetchForNewUserChat() -> Observable<Any?> {
    return Observable.create { [weak self] subscriber in
      guard let s = self else { return Disposables.create() }
      s.state = .infoLoading
      
      s.getPlugin()
        .flatMap({ (plugin, bot) -> Observable<CHScript> in
          mainStore.dispatchOnMain(GetPlugin(plugin: plugin, bot: bot))
          return s.getWelcomeScript()
        })
        .subscribe(onNext: { (script) in
          s.didFetchInfo = true
          s.state = .infoLoaded
          mainStore.dispatchOnMain(GetScript(payload: script))
          subscriber.onNext(nil)
        }, onError: { (error) in
          s.didFetchInfo = false
          s.state = .infoNotLoaded
          subscriber.onError(error)
        }).disposed(by: s.disposeBag)
      
      return Disposables.create()
    }
  }
  
  func fetchChat() -> Observable<ChatResponse> {
    return Observable.create { [weak self] subscriber in
      guard self?.state != .chatLoading else { return Disposables.create() }
      guard let s = self else  { return Disposables.create() }
      s.state = .chatLoading
      
      CHUserChat.get(userChatId: s.chatId)
        .subscribe(onNext: { (response) in
          s.state = .chatLoaded
          s.didChatLoaded = true
          mainStore.dispatch(GetUserChat(payload: response))
          subscriber.onNext(response)
        }, onError: { (error) in
          s.state = .chatNotLoaded
          s.didChatLoaded = false
          subscriber.onError(error)
        }).disposed(by: s.disposeBag)
      
      return Disposables.create()
    }
  }
  
  func createChat(
    pluginId: String = "",
    userOpenAt: Date? = nil,
    completion: @escaping (String?) -> Void) {
    if self.chatId != "" {
      completion(self.chatId)
      return;
    }
    
    CHUserChat.create(
      pluginId: mainStore.state.plugin.id,
      timeStamp: userOpenAt)
      .subscribe(onNext: { [weak self] (chatResponse) in
        guard let userChat = chatResponse.userChat,
          let session = chatResponse.session else { return }
        self?.chatId = userChat.id
        self?.chat = userChat
        self?.didChatLoaded = true
        mainStore.dispatch(CreateUserChat(payload: userChat))
        mainStore.dispatch(CreateSession(payload: session))
        WsService.shared.join(chatId: userChat.id)
        
        completion(userChat.id)
      }, onError: { [weak self] (error) in
        self?.didChatLoaded = false
        self?.state = .chatNotLoaded
        completion(nil)
      }).disposed(by: self.disposeBag)
  }
  
  func getPlugin() -> Observable<(CHPlugin, CHBot?)> {
    return PluginPromise.getPlugin(pluginId: mainStore.state.plugin.id)
  }
  
  func getWelcomeScript() -> Observable<CHScript> {
    let scriptKey = mainStore.state.guest.ghost ? "welcome_ghost" : "welcome"
    return ScriptPromise.get(pluginId: mainStore.state.plugin.id, scriptKey: scriptKey)
  }
}
