//
//  SFOMuseum.swift
//  wunderkammer
//
//  Created by asc on 6/24/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import CoreNFC
import URITemplate

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
    
    public func Collection() -> String {
        return "SFO Museum"
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
    
    public func HasCapability(capability: CollectionCapabilities) -> Result<Bool, Error> {
        
        switch capability {
        case CollectionCapabilities.nfcTags:
            return .success(false)
        case CollectionCapabilities.randomObject:
            return .success(true)
        case CollectionCapabilities.saveObject:
            return .success(false)
        }
    }
    
    public func NFCTagTemplate() -> Result<URITemplate, Error> {
        return .failure(CollectionErrors.notImplemented)
    }
    
    public func ObjectURLTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "https://millsfield.sfomuseum.org/objects/{objectid}")
        return .success(t)
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
    
    public func GetRandomURL(completion: (Result<URL, Error>) -> ()) {
        
        let str_url = "https://millsfield.sfomuseum.org/oembed?url=https://millsfield.sfomuseum.org/random"
        
        guard let url = URL(string: str_url) else {
            completion(.failure(SFOMuseumErrors.invalidURL))
            return
        }
        
        completion(.success(url))
        return
    }
    
    public func SaveObject(object: CollectionObject) -> Result<CollectionObjectSaveResponse, Error> {
        return .success(CollectionObjectSaveResponse.noop)
    }
    
}
