//
//  UIImageView.swift
//  wunderkammer
//
//  Created by asc on 7/1/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import UIKit

// https://stackoverflow.com/questions/30014241/uiimageview-pinch-zoom-swift

extension UIImageView {
  func enableZoom() {
    let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(startZooming(_:)))
    isUserInteractionEnabled = true
    addGestureRecognizer(pinchGesture)
  }

  @objc
  private func startZooming(_ sender: UIPinchGestureRecognizer) {
    let scaleResult = sender.view?.transform.scaledBy(x: sender.scale, y: sender.scale)
    guard let scale = scaleResult, scale.a > 1, scale.d > 1 else { return }
    sender.view?.transform = scale
    sender.scale = 1
  }
}

