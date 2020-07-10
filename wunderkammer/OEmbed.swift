//
//  OEmbed.swift
//  shoebox
//
//  Created by asc on 6/10/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation

public struct OEmbedResponse: Codable {
    var version: String
    var type: String
    var provider_name: String
    var title: String
    var author_url: String? // SFO Museum but not Cooper Hewitt
    var url: String
    var height: Int
    var width: Int
    var thumbnail_url: String?
    var object_url: String? // Cooper Hewitt
    var object_id: String?  // Cooper Hewitt
    var object_uri: String? // wunderkammer
    var data_url: String? // wunderkammer    
}

public class OEmbed {
    
    public init() {
        
    }
    
    public func Fetch(url: URL) -> Result<OEmbedResponse, Error> {
        
        var oembed_data: Data?
        
        do {
            oembed_data = try Data(contentsOf: url)
            // let oembed_str = String(decoding: oembed_data!, as: UTF8.self)
            // print("DATA", oembed_str)
        } catch(let error){
            
            return .failure(error)
        }
        
        return self.ParseOEmbed(data: oembed_data!)
    }
    
    public func ParseOEmbed(data: Data) -> Result<OEmbedResponse, Error> {
        
        let decoder = JSONDecoder()
        var oembed: OEmbedResponse
        
        do {
            oembed = try decoder.decode(OEmbedResponse.self, from: data)
        } catch(let error) {
            return .failure(error)
        }
        
        return .success(oembed)
    }
}

