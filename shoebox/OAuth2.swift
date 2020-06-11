//
//  OAuth2.swift
//  shoebox
//
//  Created by asc on 6/11/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation

struct OAuth2Token: Codable {
    var access_token: String
    var expires: Int
    var scope: String
}
