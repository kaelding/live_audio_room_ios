//
//  ZegoDefine.swift
//  ZegoLiveAudioRoomDemo
//
//  Created by Kael Ding on 2021/12/13.
//

import Foundation

/// common room callback
typealias RoomCallback = (Result<Void, ZegoError>) -> Void

/// online room users callback
typealias OnlineRoomUsersCallback = (Result<UInt32, ZegoError>) -> Void


enum ZegoError: Error {
        
    /// common failed
    case failed
    case roomExisted
    case roomNotFound
    case takeSeatFailed
    case setSeatInfoFailed
    case alreadyOnSeat
    case noPermission
    case notOnSeat
    case paramInvalid
    
    /// other error code
    case other(_ rawValue: Int32)
    
    var code: Int32 {
        switch self {
        case .failed: return 1
        case .roomExisted: return 1001
        case .roomNotFound: return 1002
        case .takeSeatFailed: return 2001
        case .setSeatInfoFailed: return 2002
        case .alreadyOnSeat: return 2003
        case .noPermission: return 2004
        case .notOnSeat: return 2005
        case .paramInvalid: return 2006
        case .other(let rawValue): return rawValue
        }
    }
}
