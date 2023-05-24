//
//  NotificationExtensions.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 03/05/2023.
//

import Foundation

protocol DeviceNotifiable {
    associatedtype T
    static var name: Notification.Name { get }
    var payload: T { get }
}

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

struct NextJourneyNotify: DeviceNotifiable {
    static let name = NSNotification.Name ("nextJourney")
    typealias T = Void
    let payload: T
    init () {}
}

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

struct VideoPlayingStatusChange: DeviceNotifiable {
    static let name = NSNotification.Name ("videoPlayingStatusChange")
    typealias T = Void
    let payload: T
    init () {}
}

struct EnvironmentChangedNotify: DeviceNotifiable {
    static let name = NSNotification.Name ("environmentChanged")
    typealias T = Void
    let payload: T
    init () {}
}


