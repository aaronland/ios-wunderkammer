//
//  Smithsonian.swift
//  wunderkammer
//
//  Created by asc on 7/2/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import CoreNFC
import UIKit

import URITemplate
import FMDB

public enum SmithsonianErrors: Error {
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

public class SmithsonianOEmbed: CollectionOEmbed {
    
    private var oembed: OEmbedResponse
    
    public init?(oembed: OEmbedResponse) {
        
        guard let _ = oembed.object_uri else {
            return nil
        }
        
        self.oembed = oembed
    }
    
    public func Collection() -> String {
        return "Smithsonian Institution"
    }
    
    public func ObjectID() -> String {
        return self.oembed.object_uri!
    }
    
    public func ObjectURL() -> String {
        return self.oembed.author_url!
    }
    
    public func ObjectURI() -> String {
        
        // PLEASE RECONCILE ME WITH NFCTagTemplate BELOW
        // HOW TO... what if no collection?
        
        guard let object_uri = self.oembed.object_uri else {
            let t = URITemplate(template: "si://{collection}/o/{objectid}")
            return t.expand(["objectid":self.ObjectID(), "collection":""])
        }
        
        return object_uri
    }
    
    public func ObjectTitle() -> String {
        return self.oembed.title
    }
    
    public func ImageURL() -> String {
        // because: https://github.com/Smithsonian/OpenAccess/issues/6
        var url = self.oembed.url
        url = url.replacingOccurrences(of: "http://", with: "https://")
        return url
    }
    
    public func Raw() -> OEmbedResponse {
        return self.oembed
    }
}

public class SmithsonianCollection: Collection {
    
    private var databases = [String:FMDatabase]()
    
    public init?() {
        
        let fm = FileManager.default
        
        let paths = fm.urls(for: .documentDirectory, in: .userDomainMask)
        let first = paths[0]
        
        let si = first.appendingPathComponent("smithsonian")
      
        if !fm.fileExists(atPath: si.path){
            print("Missing Smithsonian databases")
            return nil
        }
        
        var db_uris = [URL]()
        
        do {
            
            let contents = try fm.contentsOfDirectory(at: si, includingPropertiesForKeys: nil)
            
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
                 
            // print("DB", db_uri)
            
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
    
    private func deriveUnitFromURL(url: URL) -> Result<String, Error> {
        
        guard let id = url.queryParameters["id"] else {
            return .failure(SmithsonianErrors.missingUnitID)
        }
        
        let parts = id.components(separatedBy: "-")
        let unit = parts[0]
        
        return .success(unit)
    }
    
    private func getRandomURL(database: FMDatabase) -> Result<URL, Error>{
        
        let q = "SELECT url FROM oembed ORDER BY RANDOM() LIMIT 1"
        
        var str_url: String?
        
        do {
            let rs = try database.executeQuery(q, values: nil)
            rs.next()
            
            guard let u = rs.string(forColumn: "url") else {
                return .failure(SmithsonianErrors.invalidURL)
            }
            
            str_url = u
            
        } catch (let error) {
            return .failure(error)
        }
        
        guard let url = URL(string: str_url!) else {
            return .failure(SmithsonianErrors.invalidURL)
        }
        
        return .success(url)
    }
    
    public func SaveObject(oembed: CollectionOEmbed, image: UIImage?) -> Result<CollectionSaveObjectResponse, Error> {
        return .success(CollectionSaveObjectResponse.noop)
    }
    
    public func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error> {
                
        // this works: GET https://ids.si.edu/ids/download?id=SAAM-1971.456.11_2_screen
        // this doesn't: GET oembed:///?url=si%3A%2F%2Fnmaahc%2Fo%2FA2018_24_1_1_1ab
        // as in: "si://nmaahc/o/A2018_24_1_1_1ab"
         
        // here is the crux of it: from 'url' we need to determine what the
        // query field is - (image) url or (object) id - and whether the
        // query value needs to be derived/extracted from 'url'
        
        var q = "SELECT body FROM oembed WHERE url = ?"
        
        var unit: String?   // the database to read from
        var target: Any     // the value we are going to query against
                
        if url.scheme == "nfc" {
                    
            // query for the object
            
            let params = url.queryParameters
                        
            guard let nfc_url = params["url"] else {
                return .failure(SmithsonianErrors.missingOEmbedQueryParameter)
            }
                        
            let template_result = self.NFCTagTemplate()
            
            switch template_result {
            case .failure(let error):
                return .failure(error)
            case .success(let template):
                                
                guard let nfc_variables = template.extract(nfc_url) else {
                    return .failure(SmithsonianErrors.invalidURITemplate)
                }
                                
                guard let nfc_unit = nfc_variables["collection"] else {
                    return .failure(SmithsonianErrors.missingURITemplateVariable)
                }
                                
                unit = nfc_unit.uppercased() // sigh...
                target = nfc_url
                
                q = "SELECT body FROM oembed WHERE object_uri = ?"
            }
            
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
            return .failure(SmithsonianErrors.missingUnitID)
        }
        
        guard let database = self.databases[unit!] else {
            return .failure(SmithsonianErrors.missingUnitDatabase)
        }
             
        // print("QUERY", unit, q, target)
        
        var oe_data: Data?
        
        do {
            let rs = try database.executeQuery(q, values: [target] )
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
    
    // remember: something like "si://nmaahc/o/A2018.24.1.1.1ab"
    // will never work because "." is a reserved character in RFC6570
    // https://tools.ietf.org/html/rfc6570#section-2.1

    public func NFCTagTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "si://{collection}/o/{objectid}")
        return .success(t)
    }
    
    public func ObjectURLTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "si://{collection}/o/{objectid}")
        return .success(t)
    }
    
    public func OEmbedURLTemplate() -> Result<URITemplate, Error> {
        let t = URITemplate(template: "nfc:///?url={url}")
        return .success(t)
    }
    
}


