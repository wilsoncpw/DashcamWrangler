//
//  NotificationExtensions.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 03/05/2023.
//

import Foundation

//---------------------------------------------------------------------
// DeviceNotifiable - base protocol for notifications
protocol DeviceNotifiable {
    associatedtype T
    static var name: Notification.Name { get }
    var payload: T { get }
}

//---------------------------------------------------------------------
// Extend the protocol with functions to post & observe
extension DeviceNotifiable {
    func post () {
        NotificationCenter.default.post(name: Self.name, object: payload)
    }
    
    static func observe (callback: @escaping (T) -> Void) -> AnyObject{
        return NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { notification in
            if let payload = notification.object as? T {
                callback (payload)
            }
        }
    }
    
    static func stopObserving (obj: AnyObject?) {
        if let obj = obj {
            NotificationCenter.default.removeObserver(obj)
        }
    }
}

//---------------------------------------------------------------------
/// Notifies that a journey has been selected in the JourneyViewController
struct JourneySelection {
    let journey: Journey
    let isFirst: Bool
    let isLast: Bool
}

struct JourneySelectedNotify: DeviceNotifiable {
    static let name = NSNotification.Name ("journeySelected")
    typealias T = JourneySelection
    let payload: T
    
    init (journey: Journey, isFirst: Bool, isLast: Bool) {
        payload = JourneySelection (journey: journey, isFirst: isFirst, isLast: isLast)
    }
}

//---------------------------------------------------------------------
/// Notifies the JourneyViewContoller to select the next journey
struct NextJourneyNotify: DeviceNotifiable {
    static let name = NSNotification.Name ("nextJourney")
    typealias T = Void
    let payload: T
    init () {}
}

//---------------------------------------------------------------------
/// Notifies the JourneyViewContoller to select the previous journey
struct PrevJourneyNotify: DeviceNotifiable {
    static let name = NSNotification.Name ("prevJourney")
    typealias T = Void
    let payload: T
    init () {}
}

struct VideoTickNotify: DeviceNotifiable {
    static let name = NSNotification.Name ("videoTick")
    typealias T = Void
    let payload: T
    init () {}
}

//---------------------------------------------------------------------
/// Notifies that the video player has stoped or started
struct VideoPlayingStatusChange: DeviceNotifiable {
    static let name = NSNotification.Name ("videoPlayingStatusChange")
    typealias T = Void
    let payload: T
    init () {}
}

struct DeleteJourneyNotify: DeviceNotifiable {
    static let name = NSNotification.Name ("DeleteJourney")
    typealias T = Journey
    let payload: T
    init (journey: Journey) { payload = journey }
}

