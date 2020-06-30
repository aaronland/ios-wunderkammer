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

public enum WunderkammerErrors: Error {
    case notImplemented
}

public class Wunderkammer: Collection  {

    private let objects_schema = "CREATE TABLE objects(url TEXT PRIMARY KEY, id TEXT, image TEXT, created DATE)"
    private var database: FMDatabase
    
    public init?() {
        
        let fileURL = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("wunderkammer.sqlite")
        
        // print(fileURL)
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
    
    public func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error> {
        return .failure(WunderkammerErrors.notImplemented)
    }
    
    public func GetRandomURL(completion: (Result<URL, Error>) -> ()) {
        completion(.failure(WunderkammerErrors.notImplemented))
        return
    }
    
    public func ParseNFCTag(message: NFCNDEFMessage) -> Result<URL, Error> {
        return .failure(WunderkammerErrors.notImplemented)
    }
    
    public func SaveObject(object: CollectionObject) -> Result<CollectionObjectSaveResponse, Error> {
        
        do {
            try self.database.executeUpdate("INSERT OR REPLACE INTO objects (url, id, image) values (?, ?, ?)", values: [object.URL, object.ID, object.Image])
        } catch (let error) {
            return .failure(error)
        }

        return .success(CollectionObjectSaveResponse.success)
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


