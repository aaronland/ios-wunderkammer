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
              
        processTag()
    }
    
    func processTag() {
        
        print("PROCESS")
        
        let object_id = "18704235"
            
            let str_url = String(format: "https://collection.cooperhewitt.org/oembed/photo/?url=https://collection.cooperhewitt.org/objects/%@", object_id)
                    
            guard let url = URL(string: str_url) else {
                print("SAD")
                return
            }
        
            fetchOEmbed(url: url)
    }
    
    private func fetchOEmbed(url: URL) {
        
        print("FETCH DISPATCH")
        
        DispatchQueue.global().async { [weak self] in
            
            print("FETCH DONE")
            
            if let data = try? Data(contentsOf: url) {
                
                let oembed_rsp = self?.parseOEmbed(data: data)
                
                switch oembed_rsp {
                case .failure(let error):
                    print("SAD", error)
                case .success(let oembed):
                    self?.displayOEmbed(oembed: oembed)
                default:
                    ()
                }
                
            }
        }
    }
    
    private func parseOEmbed(data: Data) -> Result<OEmbed, Error> {
        
        print("PARSE")
        
        let decoder = JSONDecoder()
        var oembed: OEmbed
        
        do {
            oembed = try decoder.decode(OEmbed.self, from: data)
        } catch(let error) {
            return .failure(error)
        }
        
        return .success(oembed)
    }
    
    private func displayOEmbed(oembed: OEmbed) {
        
        print("DISPLAY")
        
        guard let url = URL(string: oembed.url) else {
            print("SAD URL")
            return
        }
        
        DispatchQueue.main.async {
            self.loadImage(url: url)
        }
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
