//
//  Wunderkammer.swift
//  wunderkammer
//
//  Created by asc on 6/14/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import FMDB

class Wunderkammer {
    
    private let objects_schema = ""
    private var database: FMDatabase
    
    public init?() {
        
        let fileURL = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("wunderkammer.sqlite")
        
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
                print("OKAY TABLE")
            }
        }
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


