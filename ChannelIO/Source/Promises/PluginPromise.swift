//
//  PluginPromise.swift
//  CHPlugin
//
//  Created by Haeun Chung on 06/02/2017.
//  Copyright © 2017 ZOYI. All rights reserved.
//

import Foundation
import Alamofire
import RxSwift
import ObjectMapper
import SwiftyJSON

struct PluginPromise {
  static func registerPushToken(channelId: String, token: String) -> Observable<Any?> {
    return Observable.create { subscriber in
      let key = UIDevice.current.identifierForVendor?.uuidString
      let params = [
        "body": [
          "channelId": channelId,
          "key": key,
          "token": token,
          "platform": "ios"
        ]
      ]
      
      let req = Alamofire.request(RestRouter.RegisterToken(
          params as RestRouter.ParametersType))
        .validate(statusCode: 200..<300)
        .responseJSON(completionHandler: { response in
          switch response.result {
          case .success(let data):
            let json = JSON(data)
            if json["deviceToken"] == JSON.null {
              subscriber.onError(CHErrorPool.registerParseError)
            }

            subscriber.onNext(nil)
            subscriber.onCompleted()
          case .failure(let error):
            subscriber.onError(error)
          }
        })
      
      return Disposables.create {
        req.cancel()
      }
    }.subscribeOn(ConcurrentDispatchQueueScheduler(qos:.background))
  }
  
  static func unregisterPushToken(guestToken: String) -> Observable<Any?> {
    return Observable.create { subscriber in
      let params = ["headers":["X-Guest-Jwt": guestToken]]
      
      let key = UIDevice.current.identifierForVendor?.uuidString ?? ""
      let req = Alamofire.request(RestRouter.UnregisterToken(key, params as RestRouter.ParametersType))
        .validate(statusCode: 200..<300)
        .responseJSON(completionHandler: { response in
          if response.response?.statusCode == 200 {
            subscriber.onNext(nil)
            subscriber.onCompleted()
          } else {
            subscriber.onError(CHErrorPool.unregisterError)
          }
        })
      
      return Disposables.create {
        req.cancel()
      }
    }.subscribeOn(ConcurrentDispatchQueueScheduler(qos:.background))
  }
  
  static func checkVersion() -> Observable<Any?> {
    return Observable.create { subscriber in
      let req = Alamofire.request(RestRouter.CheckVersion)
        .validate(statusCode: 200..<300)
        .responseJSON(completionHandler: { response in
          switch response.result {
          case .success(let data):
            let json = JSON(data)
            
            let nsObject: Any = Bundle.main.infoDictionary!["CFBundleShortVersionString"] ?? ""
            //Then just cast the object as a String, but be careful, you may want to double check for nil
            let version = nsObject as! String
            let minVersion = json["minCompatibleVersion"].string ?? ""
            
            //if minVersion is higher than version
            if version.versionToInt().lexicographicallyPrecedes(minVersion.versionToInt()) {
              subscriber.onError(CHErrorPool.versionError)
              return
            }
            
            subscriber.onNext(nil)
            subscriber.onCompleted()
            break
          case .failure(let error):
            subscriber.onError(error)
          }
        })
      
      return Disposables.create {
        req.cancel()
      }
    }.subscribeOn(ConcurrentDispatchQueueScheduler(qos:.background))
  }
  
  static func getOperators() -> Observable<[CHManager]> {
    return Observable.create { (subscriber) in
      let req = Alamofire.request(RestRouter.GetOperators)
        .validate(statusCode: 200..<300)
        .responseJSON(completionHandler: { response in
          switch response.result{
          case .success(let data):
            let json = JSON(data)
            let managers = Mapper<CHManager>()
              .mapArray(JSONObject: json["managers"].object)
            subscriber.onNext(managers ?? [])
            subscriber.onCompleted()
          case .failure(let error):
            subscriber.onError(error)
          }
        })
      return Disposables.create {
        req.cancel()
      }
    }.subscribeOn(ConcurrentDispatchQueueScheduler(qos:.background))
  }

  static func getPlugin(pluginId: String) -> Observable<(CHPlugin, CHBot?)> {
    return Observable.create { (subscriber) in
      let req = Alamofire.request(RestRouter.GetPlugin(pluginId))
        .validate(statusCode: 200..<300)
        .responseJSON(completionHandler: { response in
          switch response.result{
          case .success(let data):
            let json = JSON(data)
            guard let plugin = Mapper<CHPlugin>()
              .map(JSONObject: json["plugin"].object) else {
              subscriber.onError(CHErrorPool.pluginParseError)
              return
            }
            let bot = Mapper<CHBot>()
              .map(JSONObject: json["bot"].object)
            subscriber.onNext((plugin, bot))
            subscriber.onCompleted()
          case .failure(let error):
            subscriber.onError(error)
          }
        })
      return Disposables.create {
        req.cancel()
      }
    }.subscribeOn(ConcurrentDispatchQueueScheduler(qos:.background))
  }
  
  static func boot(pluginKey: String, params: CHParam) -> Observable<BootResult> {
    return Observable.create({ (subscriber) in      
      let req = Alamofire.request(RestRouter.Boot(pluginKey, params as RestRouter.ParametersType))
        .validate(statusCode: 200..<300)
        .responseJSON(completionHandler: { response in
          switch response.result {
          case .success(let data):
            let json = SwiftyJSON.JSON(data)
            
            guard var result = Mapper<BootResult>().map(JSONObject: json.object) else {
              subscriber.onError(CHErrorPool.pluginParseError)
              return
            }

            if result.user == nil && result.veil == nil {
              subscriber.onError(CHErrorPool.pluginParseError)
              break
            }
            
            if result.channel == nil || result.plugin == nil {
              subscriber.onError(CHErrorPool.pluginParseError)
              break
            }
            //swift bug, header should be case insensitive
            //TODO: move to request extension
            if let headers = response.response?.allHeaderFields {
              let tupleArray = headers.map { (key: AnyHashable, value: Any) in
                return ((key as? String)?.lowercased() ?? "", value)
              }
              let caseInsensitiveHeaders = Dictionary(uniqueKeysWithValues: tupleArray)
              result.guestKey = caseInsensitiveHeaders["x-guest-jwt"]
            }

            subscriber.onNext(result)
            subscriber.onCompleted()
          case .failure(let error):
            subscriber.onError(error)
          }
        })
      
      return Disposables.create {
        req.cancel()
      }
    }).subscribeOn(ConcurrentDispatchQueueScheduler(qos:.background))
  }
  
  static func sendPushAck(chatId: String?) -> Observable<Bool?> {
    return Observable.create({ (subscriber) -> Disposable in
      guard let chatId = chatId else {
        subscriber.onNext(nil)
        return Disposables.create()
      }
      
      let req = Alamofire.request(RestRouter.SendPushAck(chatId))
        .validate(statusCode: 200..<300)
        .responseJSON(completionHandler: { (response) in
          if response.response?.statusCode == 200 {
            subscriber.onNext(true)
            subscriber.onCompleted()
          } else {
            subscriber.onError(CHErrorPool.unregisterError)
          }
        })
      
      return Disposables.create {
        req.cancel()
      }
    })
  }
  
  static func getProfileSchemas(pluginId: String) -> Observable<[CHProfileSchema]> {
    return Observable.create({ (subscriber) -> Disposable in
      let req = Alamofire.request(RestRouter.GetProfileBotSchemas(pluginId))
        .validate(statusCode: 200..<300)
        .responseJSON(completionHandler: { (response) in
          switch response.result {
          case .success(let data):
            let json = SwiftyJSON.JSON(data)
            let profiles = Mapper<CHProfileSchema>().mapArray(JSONObject: json["profileBotSchemas"].object) ?? []
            subscriber.onNext(profiles)
            subscriber.onCompleted()
          case .failure(let error):
            subscriber.onError(error)
          }
        })
      return Disposables.create {
        req.cancel()
      }
    })
  }
}
