//
//  Collection.swift
//  wunderkammer
//
//  Created by asc on 6/24/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import CoreNFC

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
    case saveObject
}

public protocol CollectionOEmbed {
    func ObjectID() -> String
    func ObjectURL() -> String
    func ObjectTitle() -> String
    func ImageURL() -> String
    func Raw() -> OEmbedResponse
}

public protocol Collection {
    func GetRandomURL(completion: @escaping (Result<URL, Error>) -> ())
    func SaveObject(object: CollectionObject) -> Result<CollectionObjectSaveResponse, Error>
    func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error>
    func ParseNFCTag(message: NFCNDEFMessage) -> Result<URL, Error>
    func HasCapability(capability: CollectionCapabilities) -> Result<Bool, Error>
}
