//
//  URLExtensions.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 20/05/2023.
//

import Foundation

extension URL {
    
    enum JourneyError: Error {
        case cantSet
    }
    
    func getJourneyName () -> String? {
        let data = self.withUnsafeFileSystemRepresentation { fileSystemPath -> Data? in
            let length = getxattr(fileSystemPath, "journey", nil, 0, 0, 0)
            
            guard length > 0 else { return nil }
            
            var data = Data (count: length)
            
            let rLen = data.withUnsafeMutableBytes { bytes in
                getxattr(fileSystemPath, "journey", bytes.baseAddress, length, 0, 0)
            }
            
            guard rLen == length else { return nil }
            
            return data
        }
        
        guard let data else { return nil }
        
        return String (data: data, encoding: .utf8)
    }
    
    func setJourneyName (name: String) throws {
        
        guard let data = name.data(using: .utf8) else { throw JourneyError.cantSet }
        
        try self.withUnsafeFileSystemRepresentation { fileSystemPath in
            
            let rLen = data.withUnsafeBytes { bytes in
                setxattr(fileSystemPath, "journey", bytes.baseAddress, data.count, 0, 0)
            }
            
            if rLen < 0 {
                throw JourneyError.cantSet
            }
        }
        
    }
}
