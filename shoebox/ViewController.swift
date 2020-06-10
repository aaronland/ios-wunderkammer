//
//  ViewController.swift
//  shoebox
//
//  Created by asc on 6/9/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import UIKit
import CoreNFC

class ViewController: UIViewController, NFCNDEFReaderSessionDelegate {

    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCNDEFReaderSession?
    
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
        
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning Not Supported",
                message: "This device doesn't support tag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the item to learn more about it."
        session?.begin()
        ()
    }
    
    // MARK: - NFCNDEFReaderSessionDelegate

    /// - Tag: processingTagData
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async {
            self.detectedMessages.append(contentsOf: messages)
        }
    }

    /// - Tag: processingNDEFTag
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            // Restart polling in 500ms
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected, please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        // Connect to the found tag and perform NDEF message reading
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                if .notSupported == ndefStatus {
                    session.alertMessage = "Tag is not NDEF compliant"
                    session.invalidate()
                    return
                } else if nil != error {
                    session.alertMessage = "Unable to query NDEF status of tag"
                    session.invalidate()
                    return
                }
                
                tag.readNDEF(completionHandler: { (message: NFCNDEFMessage?, error: Error?) in
                    var statusMessage: String
                    if nil != error || nil == message {
                        statusMessage = "Fail to read NDEF from tag"
                    } else {
                        statusMessage = "Found 1 NDEF message"
                        DispatchQueue.main.async {
                            self.detectedMessages.append(message!)
                            self.processMessage(msg: message!)
                        }
                    }
                    
                    session.alertMessage = statusMessage
                    session.invalidate()
                })
            })
        })
    }
    
    /// - Tag: sessionBecomeActive
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        
    }
    
    /// - Tag: endScanning
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Check the invalidation reason from the returned error.
        if let readerError = error as? NFCReaderError {
            // Show an alert when the invalidation reason is not because of a
            // successful read during a single-tag read session, or because the
            // user canceled a multiple-tag read session from the UI or
            // programmatically using the invalidate method call.
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
                let alertController = UIAlertController(
                    title: "Session Invalidated",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }

        // To read new tags, a new session instance is required.
        self.session = nil
    }
    
    func processMessage(msg: NFCNDEFMessage) {
        
        print("PROCESS", msg)
        return

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
