//
//  ViewController.swift
//  shoebox
//
//  Created by asc on 6/9/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var scan_button: UIButton!
    
    @IBOutlet weak var scanning_indicator: UIActivityIndicatorView!
        
    @IBOutlet weak var scanned_image: UIImageView!
    
    @IBOutlet weak var scanned_meta: UITextView!
    
    @IBOutlet weak var save_button: UIButton!
    
    @IBOutlet weak var clear_button: UIButton!
    
    @IBAction func clear() {
        self.scanned_image.image = nil
        self.scanned_image.isHidden = true
        
        self.save_button.isHidden = true
        self.clear_button.isHidden = true
    }
    
    @IBAction func scanTag() {
                
        let url = URL(string: "https://aaronland.info/orthis/171/320/986/9/images/1713209869_t6Se0G4qFraAqsN3mruNCfVrnPGTBtAm_sq.jpg")
    
        loadImage(url: url!)
    }
    
    private func loadImage(url: URL) {
        
        scanning_indicator.isHidden = false
        scanning_indicator.startAnimating()
        
        self.save_button.isHidden = true
        self.clear_button.isHidden = true
        
        scanned_image.isHidden = true
        scanned_image.image = nil
                
        DispatchQueue.global().async { [weak self] in
            if let data = try? Data(contentsOf: url) {
                if let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.scanned_image.image = image
                        self?.scanned_image.isHidden = false
                        
                        self?.save_button.isHidden = false
                        self?.clear_button.isHidden = false
                        
                        self?.scanning_indicator.isHidden = true
                        self?.scanning_indicator.stopAnimating()
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scanning_indicator.isHidden = true
    }

}
