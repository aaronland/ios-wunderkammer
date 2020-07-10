//
//  CooperHewitt.swift
//  wunderkammer
//
//  Created by asc on 6/24/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import CoreNFC
import UIKit

import OAuth2Wrapper
import OAuthSwift

import CooperHewittAPI
import URITemplate

struct CooperHewittRandomObject: Codable {
    var object: CooperHewittObject
}

struct CooperHewittObject: Codable  {
    var id: String
}

public enum CooperHewittErrors: Error {
    case notImplemented
    case invalidURL
    case invalidOEmbed
    case tagUnknownURI
    case tagUnknownScheme
    case tagUnknownHost
}

public class CooperHewittOEmbed: CollectionOEmbed {
    
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
        return "Smithsonian Cooper Hewitt National Design Museum"
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

public class CooperHewittCollection: Collection {

    var oauth2_wrapper: OAuth2Wrapper
    
    public init?(oauth2_wrapper: OAuth2Wrapper) {
        self.oauth2_wrapper = oauth2_wrapper
    }
    
    public func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error> {
        
        let oembed = OEmbed()        
        let result = oembed.Fetch(url: url)
        
        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let oembed_response):
            
            guard let cooperhewitt_oembed = CooperHewittOEmbed(oembed: oembed_response) else {
                return .failure(CooperHewittErrors.invalidOEmbed)
            }
            
            return .success(cooperhewitt_oembed)
        }
    }
    
    public func NFCTagTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "chsdm:o:{objectid}")
        return .success(t)
    }
    
    public func ObjectURLTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "https://collection.cooperhewitt.org/objects/{objectid}")
        return .success(t)
    }
    
    public func OEmbedURLTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "https://collection.cooperhewitt.org/oembed/photo/?url={url}")
        return .success(t)
    }
    
    public func HasCapability(capability: CollectionCapabilities) -> Result<Bool, Error> {
        
        switch capability {
        case CollectionCapabilities.nfcTags:
            return .success(true)
        case CollectionCapabilities.randomObject:
            return .success(true)
        case CollectionCapabilities.saveObject:
            return .success(false)
        }
    }
    
    public func SaveObject(oembed: CollectionOEmbed, image: UIImage?) -> Result<CollectionSaveObjectResponse, Error> {
        
        return .success(CollectionSaveObjectResponse.noop)
        
        /*
         
         
         func doSave(creds_rsp: Result<OAuthSwiftCredential, Error>){
         
         var credentials: OAuthSwiftCredential?
         switch creds_rsp {
         case .failure(let error):
         error_remote = error
         on_complete()
         return
         case .success(let creds):
         credentials = creds
         }
         
         let api = CooperHewittAPI(access_token: credentials!.oauthToken)
         
         let method = "cooperhewitt.shoebox.items.collectItem"
         var params = [String:String]()
         params["object_id"] = self?.current_object
         
         func completion(rsp: Result<CooperHewittAPIResponse, Error>) {
         
         if case .failure(let error) = rsp {
         error_remote = error
         }
         
         on_complete()
         }
         
         api.ExecuteMethod(method: method, params: params, completion:completion)
         }
         
         self.oauth2_wrapper.GetAccessToken(completion: doSave)
         }
         */
    }
    
    public func GetRandomURL(completion: @escaping (Result<URL, Error>) -> ()) {

        func getRandom(creds_rsp: Result<OAuthSwiftCredential, Error>){
                        
            var credentials: OAuthSwiftCredential?
            switch creds_rsp {
            case .failure(let error):
                completion(.failure(error))
                return
            case .success(let creds):
                credentials = creds
            }
            
            let api = CooperHewittAPI(access_token: credentials!.oauthToken)
            
            let method = "cooperhewitt.objects.getRandom"
            var params = [String:String]()
            params["has_image"] = "1"
            
            func api_completion(api_result: Result<CooperHewittAPIResponse, Error>) {
                                
                switch api_result {
                case .failure(let error):
                    completion(.failure(error))
                    return
                    
                case .success(let api_rsp):
                    
                    let decoder = JSONDecoder()
                    var random: CooperHewittRandomObject
                    
                    do {
                        random = try decoder.decode(CooperHewittRandomObject.self, from: api_rsp.Data)
                    } catch(let error) {
                        
                        let str_data = String(decoding: api_rsp.Data, as: UTF8.self)
                        print(str_data)
                        
                        completion(.failure(error))
                        return
                    }
                    
                    let object_id = random.object.id
                    
                    let str_url = String(format: "https://collection.cooperhewitt.org/oembed/photo/?url=https://collection.cooperhewitt.org/objects/%@", object_id)
                    
                    guard let url = URL(string: str_url) else {
                        completion(.failure(CooperHewittErrors.invalidURL))
                        return
                    }
                    
                    completion(.success(url))
                }
                
            }
            
                api.ExecuteMethod(method: method, params: params, completion:api_completion)
        }
        
        self.oauth2_wrapper.GetAccessToken(completion: getRandom)
        return
    }

}
