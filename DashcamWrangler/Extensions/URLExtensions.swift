//
//  URLExtensions.swift
//  DashcamWrangler
//
//  Created by Colin Wilson on 20/05/2023.
//

import Foundation

//-------------------------------------------------------------------------------------
// Extension to get/set the journey name from a file URL's 'journey' extended attribute
extension URL {
    
    enum JourneyError: Error {
        case cantSet
    }
    
    //---------------------------------------------------------------------
    /// Get the journey name for a file URL
    /// - Returns: The journey name if one has been set for the file
    func getJourneyName () -> String? {
        
        // Get Data containing the ea
        let data = self.withUnsafeFileSystemRepresentation { fileSystemPath -> Data? in
            
            // First get the length of the journey ea
            guard case let length = getxattr(fileSystemPath, "journey", nil, 0, 0, 0), length > 0 else { return nil }
            
            // Create a buffer to receive the ea
            var data = Data (count: length)
            
            // Get the ea
            let rLen = data.withUnsafeMutableBytes { bytes in
                getxattr(fileSystemPath, "journey", bytes.baseAddress, length, 0, 0)
            }
            
            // Check that the returned length is what we expected from the previous call
            guard rLen == length else { return nil }
            
            return data
        }
        
        guard let data else { return nil }
        
        // Return string represntaion of the data
        return String (data: data, encoding: .utf8)
    }
    
    //---------------------------------------------------------------------
    /// Set the journey name for a file URL
    /// - Parameter name: The journey name to set
    func setJourneyName (name: String) throws {
        
        // Using the file system path from the URL (if its a file URL) ...
        try self.withUnsafeFileSystemRepresentation { fileSystemPath in
            
            // Get data reprentation of the name string
            guard let data = name.data(using: .utf8) else { throw JourneyError.cantSet }

            // Set the ea
            let rLen = data.withUnsafeBytes { bytes in
                setxattr(fileSystemPath, "journey", bytes.baseAddress, data.count, 0, 0)
            }
            
            // Check that the 'set' worked.
            if rLen < 0 { throw JourneyError.cantSet }
        }
        
    }
}
