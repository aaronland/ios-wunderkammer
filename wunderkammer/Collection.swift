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
import UIKit

public enum CollectionSaveObjectResponse {
    case success
    case noop
}

public enum CollectionCapabilities {
    case nfcTags
    case bleTags
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
    func ObjectURI() -> String
    func Collection() -> String
    func ImageURL() -> String
    func Raw() -> OEmbedResponse
}

public protocol Collection {
    func GetRandomURL(completion: @escaping (Result<URL, Error>) -> ())
    
    // does this need to be async with a completion handler? probably...
    func SaveObject(oembed: CollectionOEmbed, image: UIImage?) -> Result<CollectionSaveObjectResponse, Error>
    
    // TBD: return multiple OEmbed things to account for objects with multiple
    // representations...
    
    func GetOEmbed(url: URL) -> Result<CollectionOEmbed, Error>
    func HasCapability(capability: CollectionCapabilities) -> Result<Bool, Error>
    func NFCTagTemplate() -> Result<URITemplate, Error>
    func ObjectURLTemplate() -> Result<URITemplate, Error>
    func OEmbedURLTemplate() -> Result<URITemplate, Error>
}
