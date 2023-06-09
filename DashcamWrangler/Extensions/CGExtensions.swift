//
//  CGExtensions.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 03/05/2023.
//

import Foundation
import AVFoundation

extension CGLineCap  {
    //---------------------------------------------------------------------
    /// Initialise from CAShapeLayer
    /// - Parameter cap: The cap to initialise from
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
    //---------------------------------------------------------------------
    /// Initialise from CAShapeLayer
    /// - Parameter join: The join to initialize from
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
    //---------------------------------------------------------------------
    /// Add constraints to this layer to fill the super layer
    /// - Parameters:
    ///   - leftMargin: Margins
    ///   - topMargin: ""
    ///   - rightMargin: ""
    ///   - bottomMargin: ""
    func addConstraintsToFillSuperlayer (leftMargin: CGFloat, topMargin: CGFloat, rightMargin: CGFloat, bottomMargin: CGFloat) {
        addConstraint(CAConstraint (attribute: .minX, relativeTo: "superlayer", attribute: .minX, offset:leftMargin))
        addConstraint(CAConstraint (attribute: .minY, relativeTo: "superlayer", attribute: .minY, offset:bottomMargin))
        addConstraint(CAConstraint (attribute: .maxX, relativeTo: "superlayer", attribute: .maxX, offset:-rightMargin))
        addConstraint(CAConstraint (attribute: .maxY, relativeTo: "superlayer", attribute: .maxY, offset:-topMargin))
    }
}
