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
}

public class CooperHewittCollection: Collection {
    
    public init() {
        
    }
    
    public func SaveObject(id: String) -> Result<Bool, Error> {
        return .failure(CooperHewittErrors.notImplemented)
        
        /*
         
         var error_local: Error?
         var error_remote: Error?
         
         func error_message(error: Error) -> String {
             
             switch error {
             case is CooperHewittAPIError:
                 let api_error = error as! CooperHewittAPIError
                 return api_error.Message
             default:
                 return error.localizedDescription
             }
         }
         
         func on_complete() {
             
             completed += 1
             
             if completed < 2 {
                 return
             }
             
             DispatchQueue.main.async {
                 
                 self.save_button.isEnabled = true
                 
                 if error_local != nil && error_remote != nil {
                     
                     let message = String(format:"%@ (local) %@ (remote)", error_message(error: error_local!), error_message(error: error_remote!))
                     
                     self.showAlert(label: "There were multiple problem saving this object remotely.", message: message)
                     
                 } else if error_remote != nil {
                     
                     self.showAlert(label: "This object was saved to your device but there was a problem saving this object remotely.", message: error_message(error: error_remote!))
                     
                 } else if error_local != nil {
                     
                     self.showAlert(label: "This object was saved remotely but there was a problem saving this object to your device.", message: error_message(error: error_local!))
                     
                 } else {
                     self.showAlert(label: "This object has been saved.", message: "This object has been saved locally and remotely")
                 }
                 
             }
         }
         
         DispatchQueue.global().async { [weak self] in
             
             let rsp = self?.addToWunderkammer()
             
             DispatchQueue.main.async {
                 
                 if case .failure(let error) = rsp {
                     error_local = error
                 }
                 
                 on_complete()
             }
         }
         
         DispatchQueue.global().async { [weak self] in
             
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
             
             DispatchQueue.main.async {
                 self?.app.logger.debug("Get credentials to save object")
                 self?.oauth2_wrapper!.GetAccessToken(completion: doSave)
             }
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
