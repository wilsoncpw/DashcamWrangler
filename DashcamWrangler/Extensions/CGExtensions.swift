//
//  CGExtensions.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 03/05/2023.
//

import Foundation
import AVFoundation

extension CGLineCap  {
    init (from cap: CAShapeLayerLineCap) {
        switch cap {
        case .butt: self = .butt
        case .round: self = .round
        case .square: self = .square
        default: self = .butt
        }
    }
}

extension CGLineJoin {
    init (from join: CAShapeLayerLineJoin) {
        switch join {
        case .bevel: self = .bevel
        case .miter: self = .miter
        case .round: self = .round
        default: self = .miter
        }
    }
}

extension CALayer {
    func addConstraintsToFillSuperlayer (leftMargin: CGFloat, topMargin: CGFloat, rightMargin: CGFloat, bottomMargin: CGFloat) {
        addConstraint(CAConstraint (attribute: .minX, relativeTo: "superlayer", attribute: .minX, offset:leftMargin))
        addConstraint(CAConstraint (attribute: .minY, relativeTo: "superlayer", attribute: .minY, offset:bottomMargin))
        addConstraint(CAConstraint (attribute: .maxX, relativeTo: "superlayer", attribute: .maxX, offset:-rightMargin))
        addConstraint(CAConstraint (attribute: .maxY, relativeTo: "superlayer", attribute: .maxY, offset:-topMargin))
    }
}
