//
//  CooperHewitt.swift
//  wunderkammer
//
//  Created by asc on 6/24/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import CoreNFC

import URITemplate

public enum OrThisErrors: Error {
    case notImplemented
    case invalidURL
    case invalidOEmbed
    case tagUnknownURI
    case tagUnknownScheme
    case tagUnknownHost
}

public class OrThisOEmbed: CollectionOEmbed {
    
    private var oembed: OEmbedResponse
    
    public init?(oembed: OEmbedResponse) {
        
        guard let _ = oembed.object_url else {
            return nil
        }
        
        guard let _ = oembed.object_id else {
            return nil
        }
        
        self.oembed = oembed
    }
    
    public func Collection() -> String {
        return "Or This..."
    }
    
    public func ObjectID() -> String {
        return self.oembed.object_id!
    }
    
    public func ObjectURL() -> String {
        return self.oembed.object_url!
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

public class OrThis: Collection {

    
    public init?() {
    }
    
    public func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error> {
        
        let oembed = OEmbed()
        let result = oembed.Fetch(url: url)
        
        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let oembed_response):
            
            guard let orthis_oembed = OrThisOEmbed(oembed: oembed_response) else {
                return .failure(OrThisErrors.invalidOEmbed)
            }
            
            return .success(orthis_oembed)
        }
    }
    
    public func NFCTagTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "orthis://{object_id}")
        return .success(t)
    }
    
    public func ObjectURLTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "https://aaronland.info/orthis/{objectid}")
        return .success(t)
    }
    
    public func OEmbedURLTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "https://aaronland.info/orthis/oembed/?url={url}")
        return .success(t)
    }
    
    public func HasCapability(capability: CollectionCapabilities) -> Result<Bool, Error> {
        
        switch capability {
        case CollectionCapabilities.nfcTags:
            return .success(true)
        case CollectionCapabilities.randomObject:
            return .success(false)
        case CollectionCapabilities.saveObject:
            return .success(false)
        }
    }
    
    public func SaveObject(object: CollectionObject) -> Result<CollectionObjectSaveResponse, Error> {
        
        return .success(CollectionObjectSaveResponse.noop)
    }
    
    public func GetRandomURL(completion: @escaping (Result<URL, Error>) -> ()) {
        completion(.failure(OrThisErrors.notImplemented))
        return
    }

}
