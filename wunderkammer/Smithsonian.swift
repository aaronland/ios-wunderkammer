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
    case missingUnitID
    case missingUnitDatabase
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
        return "Smithsonian Institution"
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
    
    private var databases = [String:FMDatabase]()
    // private var database: FMDatabase
    
    public init?() {
        
        let fm = FileManager.default
        
        let paths = fm.urls(for: .documentDirectory, in: .userDomainMask)
        let first = paths[0]
        
        /*
         
         one large (like 1.5GB) database is too big and there should be
         a bunch of smaller per-unit databases (20200702/straup)
         
         */
        
        let si = first.appendingPathComponent("smithsonian")
        
        if !fm.fileExists(atPath: si.path){
            print("Missing Smithsonian databases")
            return nil
        }
        
        var db_uris = [URL]()
        
        do {
            
            let contents = try fm.contentsOfDirectory(at: si, includingPropertiesForKeys: nil)
            
            db_uris = contents.filter{ $0.pathExtension == ".db" }
            
        } catch (let error) {
            print("SAD", error)
            return nil
        }
        
        if db_uris.count == 0 {
            print("NO DATABASES")
            return nil
        }
        
        // this assumes (n) databases produced by
        // https://github.com/aaronland/go-smithsonian-openaccess-database
        
        for db_uri in db_uris {
            
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
                
                guard let id = url.queryParameters["id"] else {
                    print("NO ID")
                    return nil
                }
                
                let parts = id.components(separatedBy: "-")
                let unit = parts[0]
                
                self.databases[unit] = db
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
    
    public func SaveObject(object: CollectionObject) -> Result<CollectionObjectSaveResponse, Error> {
        return .success(CollectionObjectSaveResponse.noop)
    }
    
    public func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error> {
        
        guard let id = url.queryParameters["id"] else {
            return .failure(SmithsonianErrors.missingUnitID)
        }
        
        let parts = id.components(separatedBy: "-")
        let unit = parts[0]
        
        guard let database = self.databases[unit] else {            
            return .failure(SmithsonianErrors.missingUnitDatabase)
        }
        
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

extension URL {
    var queryParameters: QueryParameters { return QueryParameters(url: self) }
}

class QueryParameters {
    let queryItems: [URLQueryItem]
    init(url: URL?) {
        queryItems = URLComponents(string: url?.absoluteString ?? "")?.queryItems ?? []
        print(queryItems)
    }
    subscript(name: String) -> String? {
        return queryItems.first(where: { $0.name == name })?.value
    }
}
