//
//  CooperHewitt.swift
//  wunderkammer
//
//  Created by asc on 6/24/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation

public enum CooperHewittErrors: Error {
    case notImplemented
    case invalidOEmbed
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
    
    public init?() {
        
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
    
    public func SaveObject(object: CollectionObject) -> Result<CollectionObjectSaveResponse, Error> {
        return .failure(CooperHewittErrors.notImplemented)
        
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
             
                 self?.oauth2_wrapper!.GetAccessToken(completion: doSave)
         }
         */
    }
    
    public func GetRandom() -> Result<URL, Error> {
        
        return .failure(CooperHewittErrors.notImplemented)
        
        /*
         
         func getRandom(creds_rsp: Result<OAuthSwiftCredential, Error>){
             
             var credentials: OAuthSwiftCredential?
             switch creds_rsp {
             case .failure(let error):
                 
                 DispatchQueue.main.async {
                     self.random_button.isEnabled = true
                     self.stopSpinner()
                     self.showAlert(label:"There was a problem authorizing your account", message: error.localizedDescription)
                 }
                 
                 return
             case .success(let creds):
                 credentials = creds
             }
             
             let api = CooperHewittAPI(access_token: credentials!.oauthToken)
             
             let method = "cooperhewitt.objects.getRandom"
             var params = [String:String]()
             params["has_image"] = "1"
             
             func completion(result: Result<CooperHewittAPIResponse, Error>) {
                 
                 DispatchQueue.main.async {
                     self.random_button.isEnabled = true
                     self.stopSpinner()
                 }
                 
                 switch result {
                 case .failure(let error):
                     DispatchQueue.main.async {
                         self.showAlert(label:"There was a problem getting a random image", message: error.localizedDescription)
                     }
                     
                     return
                     
                 case .success(let api_rsp):
                     
                     let decoder = JSONDecoder()
                     var random: CooperHewittRandomObject
                     
                     do {
                         random = try decoder.decode(CooperHewittRandomObject.self, from: api_rsp.Data)
                     } catch(let error) {
                         
                         let str_data = String(decoding: api_rsp.Data, as: UTF8.self)
                         print(str_data)
                         
                         DispatchQueue.main.async {
                             self.showAlert(label:"There was problem understand the random image", message: error.localizedDescription)
                         }
                         return
                     }
                     
                     // TO DO : PARSE THE OBJECT RESPONSE FOR ALL THE STUFF IN THE OEMBED THINGY
                     
                     let object_id = random.object.id
                     self.current_object = object_id
                     
                     let str_url = String(format: "https://collection.cooperhewitt.org/oembed/photo/?url=https://collection.cooperhewitt.org/objects/%@", object_id)
                     
                     guard let url = URL(string: str_url) else {
                         DispatchQueue.main.async {
                             self.showAlert(label:"There was problem generating the URL for a random image", message: ViewControllerErrors.invalidURL.localizedDescription)
                         }
                         
                         return
                     }
                     
                     fetchOEmbed(url: url)
                 }
                 
                 
             }
             
             api.ExecuteMethod(method: method, params: params, completion:completion)
         }
         
         self.oauth2_wrapper!.GetAccessToken(completion: getRandom)
         */
    }
}
