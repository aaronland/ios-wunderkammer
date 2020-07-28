//
//  MetMuseum.swift
//  wunderkammer
//
//  Created by asc on 7/11/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import CoreNFC
import UIKit

import URITemplate
import FMDB

public enum MetMuseumErrors: Error {
    case notImplemented
    case invalidURL
    case invalidOEmbed
    case missingUnitID
    case missingUnitDatabase
    case invalidOEmbedQueryParameters
    case missingOEmbedQueryParameter
    case invalidURITemplate
    case missingURITemplateVariable
}

public class MetMuseumOEmbed: CollectionOEmbed {
    
    private var oembed: OEmbedResponse
    
    // https://github.com/aaronland/ios-wunderkammer/issues/17
    
    public init?(oembed: OEmbedResponse) {
        
        guard let _ = oembed.object_uri else {
            return nil
        }

        self.oembed = oembed
    }
    
    public func Collection() -> String {
        return "Metropolitan Museum of Art"
    }
    
    public func ObjectID() -> String {
        return self.oembed.object_uri!
    }
    
    public func ObjectURL() -> String {
        return self.oembed.author_url!
    }
    
    public func ObjectTitle() -> String {
        return self.oembed.title
    }
    
    public func ObjectURI() -> String {
        
        // PLEASE RECONCILE ME WITH NFCTagTemplate BELOW
        
        guard let object_uri = self.oembed.object_uri else {
            let t = URITemplate(template: "metmuseum://o/{objectid}")
            return t.expand(["objectid":self.ObjectID()])
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

public class MetMuseumCollection: Collection {

    private var databases = [String:FMDatabase]()
    
    // https://github.com/aaronland/ios-wunderkammer/issues/17
    
    public init?() {
        
        let fm = FileManager.default
        
        let paths = fm.urls(for: .documentDirectory, in: .userDomainMask)
        let first = paths[0]
        
        let themet = first.appendingPathComponent("metmuseum")
      
        if !fm.fileExists(atPath: themet.path){
            print("Missing Or This databases")
            return nil
        }
        
        var db_uris = [URL]()
        
        do {
            
            let contents = try fm.contentsOfDirectory(at: themet, includingPropertiesForKeys: nil)
            
            db_uris = contents.filter{ $0.pathExtension == "db" }
            db_uris = contents
            
        } catch (let error) {
            print("Failed to determine databases", error)
            return nil
        }
        
        if db_uris.count == 0 {
            print("NO DATABASES")
            return nil
        }
        
        // this assumes (n) databases produced by
        // https://github.com/aaronland/go-smithsonian-openaccess-database
        
        // one large (like 1.5GB) database is too big and there should be
        // a bunch of smaller per-unit databases (20200702/straup)
        
        for db_uri in db_uris {
                 
            print("DB", db_uri)
            
            let db = FMDatabase(url: db_uri)
            
            guard db.open() else {
                print("Unable to open database")
                return nil
            }
            
            let result = getRandomURL(database: db)
            
            switch result {
            case .failure(let error):
                print(error)
                return nil
            case .success(let url):
                
                let unit_result = deriveUnitFromURL(url: url)
                
                switch unit_result {
                case .failure(let error):
                    print(error)
                    return nil
                case .success(let unit):
                    self.databases[unit] = db
                }
            }
        }
        
    }
    
    public func GetRandomURL(completion: @escaping (Result<URL, Error>) -> ()) {
        
        let keys = Array(self.databases.keys)
        let idx = keys.randomElement()!
        let database = self.databases[idx]!
        
        let result = self.getRandomURL(database: database)
        completion(result)
    }
    
    // THIS IS A SMITHSONIANISM - PLEASE FIX...
    
    private func deriveUnitFromURL(url: URL) -> Result<String, Error> {
        
        // Obviously this is not ideal...
        return .success("metmuseum")
    }
    
    private func getRandomURL(database: FMDatabase) -> Result<URL, Error>{
                
        let q = "SELECT url FROM oembed ORDER BY RANDOM() LIMIT 1"
        
        var str_url: String?
        
        do {
            let rs = try database.executeQuery(q, values: nil)
            rs.next()
            
            guard let u = rs.string(forColumn: "url") else {
                return .failure(MetMuseumErrors.invalidURL)
            }
                        
            str_url = u
            
        } catch (let error) {
            return .failure(error)
        }
        
        guard let url = URL(string: str_url!) else {
            return .failure(MetMuseumErrors.invalidURL)
        }
        
        return .success(url)
    }
    
    public func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error> {
                
        var q = "SELECT body FROM oembed WHERE url = ?"
        
        var unit: String?   // the database to read from
        var target: Any     // the value we are going to query against
                 
        if url.scheme == "nfc" {
                    
            // query for the object
            
            let params = url.queryParameters
            
            guard let nfc_url = params["url"] else {
                return .failure(MetMuseumErrors.missingOEmbedQueryParameter)
            }
                               
            q = "SELECT body FROM oembed WHERE object_uri = ?"
            target = nfc_url
            unit = "metmuseum"   // FIX ME
            
        } else {
        
            // query for a particular representation of the object
            
            let unit_result = deriveUnitFromURL(url: url)

            switch unit_result {
            case .failure(let error):
                return .failure(error)
            case .success(let u):
                unit = u
            }
            
            target = url.absoluteURL
        }
        
        if unit == nil {
            return .failure(MetMuseumErrors.missingUnitID)
        }
        
        guard let database = self.databases[unit!] else {
            return .failure(MetMuseumErrors.missingUnitDatabase)
        }
                    
        var oe_data: Data?
                
        do {
            let rs = try database.executeQuery(q, values: [target] )
            rs.next()
            
            guard let data = rs.data(forColumn: "body") else {
                return .failure(MetMuseumErrors.invalidOEmbed)
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
            
            guard let collection_oe = MetMuseumOEmbed(oembed: oe_response) else {
                    return .failure(MetMuseumErrors.invalidOEmbed)
            }
            
            return .success(collection_oe)
        }
    }
    
    public func NFCTagTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "metmuseum://o/{objectid}")
        return .success(t)
    }
    
    public func ObjectURLTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "metmuseum://o/{objectid}")
        return .success(t)
    }
    
    public func OEmbedURLTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "nfc:///?url={url}")
        return .success(t)
    }
    
    public func HasCapability(capability: CollectionCapabilities) -> Result<Bool, Error> {
        
        switch capability {
        case CollectionCapabilities.nfcTags:
            return .success(true)
        case CollectionCapabilities.bleTags:
            return .success(false)
        case CollectionCapabilities.randomObject:
            return .success(true)
        case CollectionCapabilities.saveObject:
            return .success(false)
        default:
            return .success(false)
        }
    }
    
    public func SaveObject(oembed: CollectionOEmbed, image: UIImage?) -> Result<CollectionSaveObjectResponse, Error> {
        
        return .success(CollectionSaveObjectResponse.noop)
    }

}
