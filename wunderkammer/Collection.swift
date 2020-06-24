//
//  Collection.swift
//  wunderkammer
//
//  Created by asc on 6/24/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation

protocol Collection {
    func GetRandom() -> Result<URL, Error>
    func SaveObject(id: String) -> Result<Bool, Error>
}
