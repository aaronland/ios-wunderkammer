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
import UIKit

public enum SFOMuseumErrors: Error {
    case notImplemented
    case invalidURL
    case invalidOEmbed
    case missingOEmbedQueryParameter
    case invalidURITemplate
    case missingURITemplateVariable
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
    
    public func ObjectURI() -> String {
        
        guard let object_uri = self.oembed.object_uri else {
            // FIX ME...
            return "x-urn:\(self.ObjectID())"
        }
        
        return object_uri
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
        case CollectionCapabilities.bleTags:
            return .success(true)
        case CollectionCapabilities.randomObject:
            return .success(true)
        case CollectionCapabilities.saveObject:
            return .success(false)
        }
    }
    
    public func NFCTagTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "sfom://o/{objectid}")
        return .success(t)
    }
    
    public func ObjectURLTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "https://millsfield.sfomuseum.org/objects/{objectid}")
        return .success(t)
    }
    
    public func OEmbedURLTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "https://millsfield.sfomuseum.org/oembed?url={url}")
        // let t = URITemplate(template: "oembed:///?url={url}")
        return .success(t)
    }
    
    public func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error> {
        
        var _url = url
        
        if url.scheme == "sfom" {
                    
            // query for the object
            
            let params = url.queryParameters
                        
            guard let nfc_url = params["url"] else {
                return .failure(SFOMuseumErrors.missingOEmbedQueryParameter)
            }
               
            var objectid: String!
            
            let template_result = self.NFCTagTemplate()
            
            switch template_result {
            case .failure(let error):
                return .failure(error)
            case .success(let template):
                                
                guard let nfc_variables = template.extract(nfc_url) else {
                    return .failure(SFOMuseumErrors.invalidURITemplate)
                }
                                
                guard let id = nfc_variables["objectid"] else {
                    return .failure(SFOMuseumErrors.missingURITemplateVariable)
                }
                 
                objectid = id
            }
            
            var sfom_template: URITemplate!
            var oembed_template: URITemplate!
                
            let sfom_result = self.ObjectURLTemplate()
                
                switch sfom_result {
                case .failure(let error):
                    return .failure(error)
                case .success(let t):
                    sfom_template = t
                }
                
                let oembed_result = self.OEmbedURLTemplate()
                
                switch oembed_result {
                case .failure(let error):
                    return .failure(error)
                case .success(let t):
                    oembed_template = t
                }
            
            var sfom_vars = [String:Any]()
            sfom_vars["objectid"] = objectid
            
            let object_url = sfom_template.expand(sfom_vars)
            
            var oembed_vars = [String:Any]()
            oembed_vars["url"] = object_url
            
            let oembed_url = oembed_template.expand(["url": object_url])
            
            guard let u = URL(string: oembed_url) else {
                return .failure(SFOMuseumErrors.invalidURITemplate)
            }
            
            _url = u
        }
                    
        let oembed = OEmbed()
        let result = oembed.Fetch(url: _url)
        
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
    
    public func SaveObject(oembed: CollectionOEmbed, image: UIImage?) -> Result<CollectionSaveObjectResponse, Error> {
        return .success(CollectionSaveObjectResponse.noop)
    }
    
}
