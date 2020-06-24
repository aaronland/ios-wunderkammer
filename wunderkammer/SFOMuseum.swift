//
//  SFOMuseum.swift
//  wunderkammer
//
//  Created by asc on 6/24/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation

public enum SFOMuseumErrors: Error {
    case notImplemented
    case invalidURL
}

public class SFOMuseumCollection: Collection {

    public init() {
        
    }
    
    public func GetRandom() -> Result<URL, Error> {
        
        let str_url = "https://millsfield.sfomuseum.org/oembed?url=https://millsfield.sfomuseum.org/random"
        
        guard let url = URL(string: str_url) else {
            return .failure(SFOMuseumErrors.invalidURL)
        }
        
        return .success(url)
    }
    
    public func SaveObject(id: String) -> Result<Bool, Error> {
        return .success(true)
    }
}
