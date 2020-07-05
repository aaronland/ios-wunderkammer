//
//  URL.swift
//  wunderkammer
//
//  Created by asc on 7/5/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation

extension URL {
    var queryParameters: QueryParameters { return QueryParameters(url: self) }
}

class QueryParameters {
    let queryItems: [URLQueryItem]
    
    init(url: URL?) {
        queryItems = URLComponents(string: url?.absoluteString ?? "")?.queryItems ?? []
    }
    
    subscript(name: String) -> String? {
        return queryItems.first(where: { $0.name == name })?.value
    }
}
