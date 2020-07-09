//
//  Collection.swift
//  wunderkammer
//
//  Created by asc on 6/24/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import CoreNFC
import URITemplate


public struct CollectionObject {
    var ID: String
    var URL: String
    var Image: String
}

public enum CollectionObjectSaveResponse {
    case success
    case noop
}

public enum CollectionCapabilities {
    case nfcTags
    case randomObject
    case saveObject
}

public enum CollectionErrors: Error {
    case notImplemented
    case unknownCapability
}

public protocol CollectionOEmbed {
    func ObjectID() -> String
    func ObjectURL() -> String
    func ObjectTitle() -> String
    func Collection() -> String
    func ImageURL() -> String
    func Raw() -> OEmbedResponse
}

public protocol Collection {
    func GetRandomURL(completion: @escaping (Result<URL, Error>) -> ())
    func SaveObject(object: CollectionObject) -> Result<CollectionObjectSaveResponse, Error>
    
    // TBD: return multiple OEmbed things to account for objects with multiple
    // representations...
    
    func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error>
    func HasCapability(capability: CollectionCapabilities) -> Result<Bool, Error>
    func NFCTagTemplate() -> Result<URITemplate, Error>
    func ObjectURLTemplate() -> Result<URITemplate, Error>
    func OEmbedURLTemplate() -> Result<URITemplate, Error>
}
