//
//  UINavigationBar.swift
//  wunderkammer
//
//  Created by asc on 7/2/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import Foundation
import UIKit

extension UINavigationBar {

    func shouldRemoveShadow(_ value: Bool) -> Void {
        if value {
            self.setValue(true, forKey: "hidesShadow")
        } else {
            self.setValue(false, forKey: "hidesShadow")
        }
    }
}
