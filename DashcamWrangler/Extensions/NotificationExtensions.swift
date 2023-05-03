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

struct JourneySelectedNotify: DeviceNotifiable {
    static let name = NSNotification.Name ("journeySelected")
    typealias T = Journey
    let payload: T
    
    init (journey: Journey) {
        payload = journey
    }
}

struct EnvironmentChangedNotify: DeviceNotifiable {
    static let name = NSNotification.Name ("environmentChanged")
    typealias T = Void
    let payload: T
    init () {}
}

