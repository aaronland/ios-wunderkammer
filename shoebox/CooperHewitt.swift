//
//  CooperHewitt.swift
//  shoebox
//
//  Created by asc on 6/11/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation

class CooperHewittAPI {
    
    var endpoint = "https://api.collection.cooperhewitt.org/rest/"
    var access_token: String?
    
    init(access_token: String) {
        self.access_token = access_token
    }
    
    public func ExecuteMethod(method: String, params: [String:String]) {
        
        let url = URL(string: self.endpoint)!
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        components.queryItems = [
            URLQueryItem(name: "method", value: method),
            URLQueryItem(name: "access_token", value: self.access_token),
        ]

        for (k, v) in params {
            components.queryItems?.append(URLQueryItem(name: k, value: v))
        }
        
        let query = components.url!.query
        
        let session = URLSession.shared
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        request.httpBody = Data(query!.utf8)

        let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in

            guard error == nil else {
                print("ERROR", error)
                return
            }

            guard let data = data else {
                print("NO DATA")
                return
            }

            let http_rsp = response as! HTTPURLResponse
            
            if http_rsp.value(forHTTPHeaderField: "StatusCode") != "200" {
                print("SAD", http_rsp.value(forHTTPHeaderField: "Status"))
                return
            }
            
                let rsp = String(decoding: data, as: UTF8.self)
                print("OKAY", rsp)

        })
        task.resume()
    }
}
