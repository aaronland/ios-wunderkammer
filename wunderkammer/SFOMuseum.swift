//
//  SFOMuseum.swift
//  wunderkammer
//
//  Created by asc on 6/24/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import CoreNFC

public enum SFOMuseumErrors: Error {
    case notImplemented
    case invalidURL
    case invalidOEmbed
}

public class SFOMuseumOEmbed: CollectionOEmbed {
    
    private var oembed: OEmbedResponse
    
    public init?(oembed: OEmbedResponse) {
        
        guard let _ = oembed.author_url else {
            return nil
        }

        self.oembed = oembed
    }
    
    public func ObjectID() -> String {
        
        let auth_url = self.oembed.author_url!
        
        let fname = (auth_url as NSString).lastPathComponent
        return fname
    }
    
    public func ObjectURL() -> String {
        return self.oembed.author_url!
    }
    
    public func ObjectTitle() -> String {
        return self.oembed.title
    }
    
    public func ImageURL() -> String {
        return self.oembed.url
    }
    
    public func Raw() -> OEmbedResponse {
        return self.oembed
    }
}

public class SFOMuseumCollection: Collection {

    public init() {
        
    }
    
    public func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error> {
        
        let oembed = OEmbed()
        let result = oembed.Fetch(url: url)
        
        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let oembed_response):
            
            guard let sfomuseum_oembed = SFOMuseumOEmbed(oembed: oembed_response) else {
                return .failure(SFOMuseumErrors.invalidOEmbed)
            }
            
            return .success(sfomuseum_oembed)
        }
    }
    
    public func GetRandom() -> Result<URL, Error> {
        
        let str_url = "https://millsfield.sfomuseum.org/oembed?url=https://millsfield.sfomuseum.org/random"
        
        guard let url = URL(string: str_url) else {
            return .failure(SFOMuseumErrors.invalidURL)
        }
        
        return .success(url)
    }
    
    public func SaveObject(object: CollectionObject) -> Result<CollectionObjectSaveResponse, Error> {
        return .success(CollectionObjectSaveResponse.noop)
    }
    
    public func ParseNFCTag(message: NFCNDEFMessage) -> Result<URL, Error> {
        return .failure(SFOMuseumErrors.notImplemented)
    }
}
