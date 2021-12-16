//
//  ZegoRoomService.swift
//  ZegoLiveAudioRoomDemo
//
//  Created by Kael Ding on 2021/12/13.
//

import Foundation
import ZIM

protocol RoomServiceDelegate: AnyObject {
    func receiveRoomInfoUpdate(_ info: RoomInfo?)
    func connectionStateChanged(_ state: ZIMConnectionState, _ event: ZIMConnectionEvent)
}

class RoomService: NSObject {
    
    // MARK: - Private
    override init() {
        super.init()
        RoomManager.shared.addZIMEventHandler(self)
    }
    
    // MARK: - Public
    
    var info: RoomInfo?
    weak var delegate: RoomServiceDelegate?
    
    /// Create a chat room
    /// You need to enter a generated `rtc token`
    func createRoom(_ roomID: String, _ roomName: String, _ token: String, callback: @escaping RoomCallback) {
        guard roomID.count != 0 else {
            callback(.failure(.paramInvalid))
            return
        }
        
        let parameters = getCreateRoomParameters(roomID, roomName)
        ZIMManager.shared.zim?.createRoom(parameters.0, config: parameters.1, callback: { fullRoomInfo, error in
            if error.code == .ZIMErrorCodeSuccess {
                
                RoomManager.shared.roomService.info = parameters.2
                RoomManager.shared.userService.localInfo?.role = .host
                RoomManager.shared.speakerService.updateSpeakerSeats(parameters.1.roomAttributes, .set)
                RoomManager.shared.setupRTCModule(with: token)
                
                callback(.success(()))
            }
            
            else {
                if error.code == .ZIMErrorCodeCreateExistRoom {
                    callback(.failure(.roomExisted))
                } else {
                    callback(.failure(.other(Int32(error.code.rawValue))))
                }
            }
        })
        
    }
    
    /// Join a chat room
    /// You need to enter a generated `rtc token`
    func joinRoom(_ roomID: String, _ roomName: String, _ token: String, callback: @escaping RoomCallback) {
        ZIMManager.shared.zim?.joinRoom(roomID, callback: { fullRoomInfo, error in
            if error.code != .ZIMErrorCodeSuccess {
                callback(.failure(.other(Int32(error.code.rawValue))))
                return
            }
            
            RoomManager.shared.roomService.info?.roomID = roomID
            RoomManager.shared.roomService.info?.roomName = roomName
            RoomManager.shared.setupRTCModule(with: token)
            callback(.success(()))
        })
    }
    
    /// Leave the chat room
    func leaveRoom(callback: @escaping RoomCallback) {
        guard let roomID = RoomManager.shared.roomService.info?.roomID else {
            assert(false, "room ID can't be nil")
            callback(.failure(.failed))
            return
        }
        
        ZIMManager.shared.zim?.leaveRoom(roomID, callback: { error in
            if error.code == .ZIMErrorCodeSuccess {
                RoomManager.shared.resetRoomData()
                callback(.success(()))
            } else {
                callback(.failure(.other(Int32(error.code.rawValue))))
            }
        })
    }
    
    /// Query the number of chat rooms available online
    func queryOnlineRoomUsers(callback: @escaping OnlineRoomUsersCallback) {
        guard let roomID = RoomManager.shared.roomService.info?.roomID else {
            assert(false, "room ID can't be nil")
            callback(.failure(.failed))
            return
        }
        
        ZIMManager.shared.zim?.queryRoomOnlineMemberCount(roomID, callback: { count, error in
            if error.code == .ZIMErrorCodeSuccess {
                callback(.success(count))
            } else {
                callback(.failure(.other(Int32(error.code.rawValue))))
            }
        })
    }
    
    /// Disable text chat for all users
    func disableTextMessage(_ isDisabled: Bool, callback: @escaping RoomCallback) {
        let parameters = getDisableTextMessageParameters(isDisabled)
        ZIMManager.shared.zim?.setRoomAttributes(parameters.0, roomID: parameters.1, config: parameters.2, callback: { error in
            if error.code == .ZIMErrorCodeSuccess {
                callback(.success(()))
            } else {
                callback(.failure(.other(Int32(error.code.rawValue))))
            }
        })
    }
}

// MARK: - Private
extension RoomService {
    
    private func getCreateRoomParameters(_ roomID: String, _ roomName: String) -> (ZIMRoomInfo, ZIMRoomAdvancedConfig, RoomInfo) {
        
        let zimRoomInfo = ZIMRoomInfo()
        zimRoomInfo.roomID = roomID
        zimRoomInfo.roomName = roomName
        
        let roomInfo = RoomInfo()
        roomInfo.hostID = RoomManager.shared.userService.localInfo?.userID
        roomInfo.roomID = roomID
        roomInfo.roomName = roomName.count > 0 ? roomName : roomID
        roomInfo.seatNum = 8
        
        let config = ZIMRoomAdvancedConfig()
        let roomInfoJson = ZegoModelTool.modelToJson(toString: roomInfo) ?? ""
        
        config.roomAttributes = ["room_info" : roomInfoJson]
        
        return (zimRoomInfo, config, roomInfo)
    }
    
    private func getDisableTextMessageParameters(_ isDisabled: Bool) -> ([String:String], String, ZIMRoomAttributesSetConfig) {
        
        let roomInfo = self.info?.copy() as? RoomInfo
        roomInfo?.isTextMessageDisabled = isDisabled
        
        let roomInfoJson = ZegoModelTool.modelToJson(toString: roomInfo) ?? ""
        
        let attributes = ["room_info" : roomInfoJson]
        
        let roomID = roomInfo?.roomID ?? ""
        
        let config = ZIMRoomAttributesSetConfig()
        config.isDeleteAfterOwnerLeft = true
        config.isForce = false
        
        return (attributes, roomID, config)
    }
}

extension RoomService: ZIMEventHandler {
    
    
}
