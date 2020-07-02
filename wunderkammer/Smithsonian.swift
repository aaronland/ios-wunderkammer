//
//  Smithsonian.swift
//  wunderkammer
//
//  Created by asc on 7/2/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import CoreNFC
import URITemplate
import FMDB

public enum SmithsonianErrors: Error {
    case notImplemented
    case invalidURL
    case invalidOEmbed
}

public class SmithsonianOEmbed: CollectionOEmbed {
    
    private var oembed: OEmbedResponse
    
    public init?(oembed: OEmbedResponse) {
        
        guard let _ = oembed.author_url else {
            return nil
        }

        self.oembed = oembed
    }
    
    public func Collection() -> String {
        return "Smithsonian Institute"
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
public class SmithsonianCollection: Collection {
    
    private var database: FMDatabase

    public init?() {
                
        let fm = FileManager.default

        let paths = fm.urls(for: .documentDirectory, in: .userDomainMask)
        let first = paths[0]
 
        /*
         
         one large (like 1.5GB) database is too big and there should be
         a bunch of smaller per-unit databases (20200702/straup)
         
         */
        
        let db_uri = first.appendingPathComponent("nasm.db")
 
        if !fm.fileExists(atPath: db_uri.path){
            print("Database does not exist")
            return nil
        }
 
        database = FMDatabase(url: db_uri)
        
        guard database.open() else {
            print("Unable to open database")
            return nil
        }
    }
    
    public func GetRandomURL(completion: @escaping (Result<URL, Error>) -> ()) {
        
        let q = "SELECT url FROM oembed ORDER BY RANDOM() LIMIT 1"
        
        var str_url: String?
        
        
        do {
            let rs = try database.executeQuery(q, values: nil)
            rs.next()

            guard let u = rs.string(forColumn: "url") else {
                completion(.failure(SmithsonianErrors.invalidURL))
                return
            }
            
            str_url = u
            
        } catch (let error) {
            completion(.failure(error))
            return
        }
        
        guard let url = URL(string: str_url!) else {
            completion(.failure(SmithsonianErrors.invalidURL))
            return
        }
        
        completion(.success(url))
        return
    }
    
    public func SaveObject(object: CollectionObject) -> Result<CollectionObjectSaveResponse, Error> {
        
        return .success(CollectionObjectSaveResponse.noop)
    }
    
    public func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error> {
        
        let q = "SELECT body FROM oembed WHERE url = ?"
        
        var oe_data: Data?
        
        do {
            let rs = try database.executeQuery(q, values: [url.absoluteURL] )
            rs.next()

            guard let data = rs.data(forColumn: "body") else {
                return .failure(SmithsonianErrors.invalidOEmbed)
            }
            
            oe_data = data
            
        } catch (let error) {
            return .failure(error)
        }
        
        let oe = OEmbed()
        
        let oe_result = oe.ParseOEmbed(data: oe_data!)
        
        switch oe_result {
        case .failure(let error):
            return .failure(error)
        case .success(let oe_response):
            
            guard let collection_oe = SmithsonianOEmbed(oembed: oe_response) else {
                return .failure(SmithsonianErrors.invalidOEmbed)
            }
            
            return .success(collection_oe)
        }
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
        return .failure(CollectionErrors.notImplemented)
    }
    
    public func OEmbedURLTemplate() -> Result<URITemplate, Error> {
        return .failure(CollectionErrors.notImplemented)
    }
    
}
