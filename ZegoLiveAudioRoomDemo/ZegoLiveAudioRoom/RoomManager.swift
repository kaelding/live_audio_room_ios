//
//  ZegoRoomManager.swift
//  ZegoLiveAudioRoomDemo
//
//  Created by Kael Ding on 2021/12/13.
//

import Foundation
import ZIM
import ZegoExpressEngine

class RoomManager: NSObject {
    static let shared = RoomManager()
    
    // MARK: - Private
    private var appSign: String?
    private var appID: UInt32 = 0
    private let rtcEventDelegates: NSHashTable<ZegoEventHandler> = NSHashTable(options: .weakMemory)
    private let zimEventDelegates: NSHashTable<ZIMEventHandler> = NSHashTable(options: .weakMemory)
    
    private override init() {
        roomService = RoomService()
        userService = UserService()
        speakerService = SpeakerSeatService()
        messageService = MessageService()
        giftService = GiftService()
        
        super.init()
    }
    
    // MARK: - Public
    var roomService: RoomService
    var userService: UserService
    var speakerService: SpeakerSeatService
    var messageService: MessageService
    var giftService: GiftService
    
    func initWithAppID(appID: UInt32, appSign: String, callback: RoomCallback) {
        if appSign.count == 0 {
            callback(.failure(.paramInvalid))
            return
        }
        
        self.appSign = appSign
        self.appID = appID
        
        ZIMManager.shared.createZIM(appID: appID)
        if ZIMManager.shared.zim == nil {
            callback(.failure(.other(1)))
        } else {
            callback(.success(()))
            ZIMManager.shared.zim?.setEventHandler(self)
        }
    }
    
    func uninit() {
        ZIMManager.shared.destoryZIM()
        resetRoomData(true)
    }
    
    func uploadLog(callback: @escaping RoomCallback) {
        ZIMManager.shared.zim?.uploadLog({ errorCode in
            if errorCode.code == .ZIMErrorCodeSuccess {
                callback(.success(()))
            } else {
                callback(.failure(.other(Int32(errorCode.code.rawValue))))
            }
        })
    }
}

extension RoomManager {
    // MARK: - Private
    func setupRTCModule(with rtcToken: String) {
        ZegoExpressEngine.createEngine(withAppID: self.appID, appSign: self.appSign!, isTestEnv: false, scenario: .general, eventHandler: self)
        
        guard let userID = RoomManager.shared.userService.localInfo?.userID else {
            assert(false, "user id can't be nil.")
            return
        }
        
        guard let roomID = RoomManager.shared.roomService.info?.roomID else {
            assert(false, "room id can't be nil.")
            return
        }
        
        // login rtc room
        let user = ZegoUser(userID: userID)
        
        let config = ZegoRoomConfig()
        config.token = rtcToken
        config.maxMemberCount = 0
        ZegoExpressEngine.shared() .loginRoom(roomID, user: user, config: config)
        
        // monitor sound level
        ZegoExpressEngine.shared().startSoundLevelMonitor(1000)
    }
        
    func resetRoomData(_ containsUserService: Bool = false) {
        ZegoExpressEngine.shared().logoutRoom()
        ZegoExpressEngine.destroy(nil)
        
        if containsUserService {
            userService = UserService()
        }
        roomService = RoomService()
        speakerService = SpeakerSeatService()
        messageService = MessageService()
        giftService = GiftService()
    }
    
    // MARK: - event handler
    func addZIMEventHandler(_ eventHandler: ZIMEventHandler?) {
        zimEventDelegates.add(eventHandler)
    }
    
    func addExpressEventHandler(_ eventHandler: ZegoEventHandler?) {
        rtcEventDelegates.add(eventHandler)
    }
}

extension RoomManager: ZegoEventHandler {
    
    func onCapturedSoundLevelUpdate(_ soundLevel: NSNumber) {
        for delegate in rtcEventDelegates.allObjects {
            delegate.onCapturedSoundLevelUpdate?(soundLevel)
        }
    }
    
    func onRemoteSoundLevelUpdate(_ soundLevels: [String : NSNumber]) {
        for delegate in rtcEventDelegates.allObjects {
            delegate.onRemoteSoundLevelUpdate?(soundLevels)
        }
    }
    
    func onRoomStreamUpdate(_ updateType: ZegoUpdateType, streamList: [ZegoStream], extendedData: [AnyHashable : Any]?, roomID: String) {
        for delegate in rtcEventDelegates.allObjects {
            delegate.onRoomStreamUpdate?(updateType, streamList: streamList, extendedData: extendedData, roomID: roomID)
        }
        
        for stream in streamList {
            if updateType == .add {
                ZegoExpressEngine.shared().startPlayingStream(stream.streamID)
            } else {
                ZegoExpressEngine.shared().stopPlayingStream(stream.streamID)
            }
        }
    }
}

extension RoomManager: ZIMEventHandler {
    func zim(_ zim: ZIM, connectionStateChanged state: ZIMConnectionState, event: ZIMConnectionEvent, extendedData: [AnyHashable : Any]) {
        for delegate in zimEventDelegates.allObjects {
            delegate.zim?(zim, connectionStateChanged: state, event: event, extendedData: extendedData)
        }
    }
    
    // MARK: - Main
    func zim(_ zim: ZIM, errorInfo: ZIMError) {
        for delegate in zimEventDelegates.allObjects {
            delegate.zim?(zim, errorInfo: errorInfo)
        }
    }
    
    func zim(_ zim: ZIM, tokenWillExpire second: UInt32) {
        for delegate in zimEventDelegates.allObjects {
            delegate.zim?(zim, tokenWillExpire: second)
        }
    }
    
    // MARK: - Message
    func zim(_ zim: ZIM, receivePeerMessage messageList: [ZIMMessage], fromUserID: String) {
        for delegate in zimEventDelegates.allObjects {
            delegate.zim?(zim, receivePeerMessage: messageList, fromUserID: fromUserID)
        }
    }
    
    func zim(_ zim: ZIM, receiveRoomMessage messageList: [ZIMMessage], fromRoomID: String) {
        for delegate in zimEventDelegates.allObjects {
            delegate.zim?(zim, receiveRoomMessage: messageList, fromRoomID: fromRoomID)
        }
    }
    
    // MARK: - Room
    func zim(_ zim: ZIM, roomMemberJoined memberList: [ZIMUserInfo], roomID: String) {
        for delegate in zimEventDelegates.allObjects {
            delegate.zim?(zim, roomMemberJoined: memberList, roomID: roomID)
        }
    }
    
    func zim(_ zim: ZIM, roomMemberLeft memberList: [ZIMUserInfo], roomID: String) {
        for delegate in zimEventDelegates.allObjects {
            delegate.zim?(zim, roomMemberLeft: memberList, roomID: roomID)
        }
    }
    
    func zim(_ zim: ZIM, roomStateChanged state: ZIMRoomState, event: ZIMRoomEvent, extendedData: [AnyHashable : Any], roomID: String) {
        for delegate in zimEventDelegates.allObjects {
            delegate.zim?(zim, roomStateChanged: state, event: event, extendedData: extendedData, roomID: roomID)
        }
    }
    
    func zim(_ zim: ZIM, roomAttributesUpdated updateInfo: ZIMRoomAttributesUpdateInfo, roomID: String) {
        for delegate in zimEventDelegates.allObjects {
            delegate.zim?(zim, roomAttributesUpdated: updateInfo, roomID: roomID)
        }
    }
    
//    func zim(_ zim: ZIM, roomAttributesBatchUpdated updateInfo: [ZIMRoomAttributesUpdateInfo], roomID: String) {
//        for delegate in zimEventDelegates.allObjects {
//            delegate.zim?(zim, roomAttributesBatchUpdated: updateInfo, roomID: roomID)
//        }
//    }
}
