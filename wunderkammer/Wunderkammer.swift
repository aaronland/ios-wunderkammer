//
//  Wunderkammer.swift
//  wunderkammer
//
//  Created by asc on 6/14/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import CoreNFC
import FMDB
import URITemplate
import UIKit

public enum WunderkammerErrors: Error {
    case notImplemented
    case imageInvalidDataURL
    case jsonEncoding
}

public class Wunderkammer: Collection  {

    // for future reference if we ever need to do "live" updates of
    // existing databases...
    // sqlite> ALTER TABLE objects RENAME COLUMN id TO object_uri;
    // sqlite> ALTER TABLE objects RENAME COLUMN url TO oembed_url;
    
    private let objects_schema = "CREATE TABLE objects(url TEXT PRIMARY KEY, object_uri TEXT, body TEXT, created DATE); CREATE INDEX `by_object` ON objects (`object_uri`);"
    
    private var database: FMDatabase
    
    public init?() {
        
        let fm = FileManager.default

        let paths = fm.urls(for: .documentDirectory, in: .userDomainMask)
        let documents = paths[0]
        
        let fileURL = documents.appendingPathComponent("wunderkammer.db")
        
        print(fileURL)
        database = FMDatabase(url: fileURL)
        
        guard database.open() else {
            print("Unable to open database")
            return nil
        }
        
        var has_objects_table = false
        
        let objects_rsp = hasTable(database: database, table_name: "objects")
        
        switch objects_rsp {
        case .failure(let error):
            print(error)
            return nil
        case .success(let b):
            has_objects_table = b
        }
        
        if !has_objects_table {
                        
            let create_rsp = createTable(database: database, schema: objects_schema)
            
            switch create_rsp {
            case .failure(let error):
                print(error)
                return nil
            case .success():
                ()
            }
        }
    }
   
    public func HasCapability(capability: CollectionCapabilities) -> Result<Bool, Error> {
        
        switch capability {
        case CollectionCapabilities.nfcTags:
            return .success(false)
        case CollectionCapabilities.randomObject:
            return .success(false)
        case CollectionCapabilities.saveObject:
            return .success(true)
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
    
    public func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error> {
        return .failure(WunderkammerErrors.notImplemented)
    }
    
    public func GetRandomURL(completion: (Result<URL, Error>) -> ()) {
        completion(.failure(WunderkammerErrors.notImplemented))
        return
    }
    
    public func SaveObject(oembed: CollectionOEmbed, image: UIImage?) -> Result<CollectionSaveObjectResponse, Error> {
        
        let oembed_url = oembed.ObjectURL()
        let object_uri = oembed.ObjectID()
        
        var raw_oembed = oembed.Raw()
        
        if image != nil {
            
            guard let data_url = image!.dataURL() else {
                return .failure(WunderkammerErrors.imageInvalidDataURL)
            }
            
            raw_oembed.data_url = data_url
        }
        
        let encoder = JSONEncoder()
        var json_oembed: String?
        
        do {
            let enc = try encoder.encode(raw_oembed)
            json_oembed = String(decoding: enc, as: UTF8.self)
        } catch (let error) {
            return .failure(error)
        }
                
        do {
            try self.database.executeUpdate("INSERT OR REPLACE INTO objects (url, object_uri, body) values (?, ?, ?)", values: [oembed_url, object_uri, json_oembed!])
        } catch (let error) {
            return .failure(error)
        }

        return .success(CollectionSaveObjectResponse.success)
    }
    
}

private func createTable(database: FMDatabase, schema: String) -> Result<Void, Error> {
    
    do {
        try database.executeUpdate(schema, values: nil)
    } catch (let error) {
        return .failure(error)
    }
    
    return .success(())
}

private func hasTable(database: FMDatabase, table_name: String) -> Result<Bool, Error> {
    
    let query = "SELECT name FROM sqlite_master WHERE type='table'"
    var rs: FMResultSet?
    
    do {
        rs = try database.executeQuery(query, values: nil)
    } catch(let error){
        return .failure(error)
    }
    
    var has_table = false
    
    while rs!.next() {
        
        if let n = rs!.string(forColumn: "name") {
            
            if n == table_name {
                has_table = true
                break
            }
        }
    }
    
    return .success(has_table)
}


