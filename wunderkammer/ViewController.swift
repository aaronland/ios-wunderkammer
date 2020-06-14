//
//  ViewController.swift
//  shoebox
//
//  Created by asc on 6/9/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import UIKit
import CoreNFC
import OAuthSwift
import OAuth2Wrapper

enum ViewControllerErrors : Error {
    case tagUnknownURI
    case tagUnknownScheme
    case tagUnknownHost
    case invalidURL
    case debugError
}

class ViewController: UIViewController, NFCNDEFReaderSessionDelegate {
    
    let app = UIApplication.shared.delegate as! AppDelegate
    
    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCNDEFReaderSession?
    
    let oauth2_id = "wunderkammer://collection.cooperhewitt.org/access_token"
    let oauth2_callback_url = "wunderkammer://oauth2"
    
    var oauth2_wrapper: OAuth2Wrapper?
    
    var current_object = ""
    
    @IBOutlet weak var scan_button: UIButton!
    @IBOutlet weak var scanning_indicator: UIActivityIndicatorView!
    
    @IBOutlet weak var scanned_image: UIImageView!
    @IBOutlet weak var scanned_meta: UITextView!
    
    @IBOutlet weak var save_button: UIButton!
    @IBOutlet weak var clear_button: UIButton!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let wrapper = OAuth2Wrapper(id: self.oauth2_id, callback_url: self.oauth2_callback_url)
        wrapper.response_type = "code"
        wrapper.allow_missing_state = true
        wrapper.require_client_secret = false
        wrapper.allow_null_expires = true
        
        self.oauth2_wrapper = wrapper
        
        scanning_indicator.isHidden = true
        
        #if targetEnvironment(simulator)
        app.logger.logLevel = .debug
        wrapper.logger.logLevel = .debug
        
        app.logger.debug("Running in simulator environment.")
        #endif
    }
    
    @IBAction func save() {
        
        func doSave(rsp: Result<OAuthSwiftCredential, Error>){
            
            switch rsp {
            case .failure(let error):
                self.showAlert(label: "Failed to retrieve credentials", message: error.localizedDescription)
            case .success(let credentials):
                self.app.logger.debug("Save object \(self.current_object) w/ credentials")
                self.addToShoebox(object_id: self.current_object, credentials: credentials)
            }
        }
        
        self.app.logger.debug("Get credentials to save object")
        self.oauth2_wrapper!.GetAccessToken(completion: doSave)
    }
    
    @IBAction func clear() {
        
        self.current_object = ""
        
        self.scanned_image.image = nil
        self.scanned_image.isHidden = true
        
        self.scanned_meta.text = ""
        self.scanned_meta.isHidden = true
        
        self.save_button.isHidden = true
        self.clear_button.isHidden = true
    }
    
    @IBAction func scanTag() {
        
        #if targetEnvironment(simulator)
        
        let object_id = "18704235"
        self.current_object = object_id
        
        self.app.logger.debug("Running in simulator mode, assume object ID \(object_id).")
        
        let str_url = String(format: "https://collection.cooperhewitt.org/oembed/photo/?url=https://collection.cooperhewitt.org/objects/%@", object_id)
        
        guard let url = URL(string: str_url) else {
            self.showError(error: ViewControllerErrors.invalidURL)
            return
        }
        
        fetchOEmbed(url: url)
        return
        
        #else
        
        guard NFCNDEFReaderSession.readingAvailable else {
            
            self.showAlert(label: "Scanning Not Supported", message: "This device doesn't support tag scanning.")
            return
        }
        
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the item to learn more about it."
        session?.begin()
        ()
        
        scanning_indicator.isHidden = false
        scanning_indicator.startAnimating()
        
        #endif
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
                        self.processMessage(message: message!)
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
                
                self.showAlert(label:"There was a problem reading tag", message: error.localizedDescription)
            }
        }
        
        // To read new tags, a new session instance is required.
        self.session = nil
        
        scanning_indicator.isHidden = true
        scanning_indicator.stopAnimating()
    }
    
    func processMessage(message: NFCNDEFMessage) {
        
        let payload = message.records[0]
        let data = payload.payload
        
        let str_data = String(decoding: data, as: UTF8.self)
        let parts = str_data.split(separator: ":")
        
        if parts.count != 3 {
            self.showError(error: ViewControllerErrors.tagUnknownURI)
            return
        }
        
        let scheme = parts[0]
        let host = parts[1]
        let path = parts[2]
        
        if scheme != "chsdm" {
            self.showAlert(label:"Failed to read tag", message:ViewControllerErrors.tagUnknownScheme.localizedDescription)
            return
        }
        
        if host != "o" {
            self.showAlert(label:"Failed to read tag", message: ViewControllerErrors.tagUnknownHost.localizedDescription)
            return
        }
        
        let object_id = String(path)
        self.current_object = object_id
        
        self.app.logger.debug("Scanned object \(object_id)")
        
        let str_url = String(format: "https://collection.cooperhewitt.org/oembed/photo/?url=https://collection.cooperhewitt.org/objects/%@", object_id)
        
        guard let url = URL(string: str_url) else {
            self.showError(error: ViewControllerErrors.invalidURL)
            return
        }
        
        fetchOEmbed(url: url)
    }
    
    private func fetchOEmbed(url: URL) {
        
        self.startSpinner()
        
        DispatchQueue.global().async { [weak self] in
            
            var oembed_data: Data?
            
            do {
                oembed_data = try Data(contentsOf: url)
            } catch(let error){
                
                DispatchQueue.main.async {
                    self?.stopSpinner()
                    self?.showAlert(label:"Unable to fetch object information", message: error.localizedDescription)
                }
                
                return
            }
            
            let oembed_rsp = self?.parseOEmbed(data: oembed_data!)
            
            switch oembed_rsp {
            case .failure(let error):
                
                self?.current_object = ""
                
                DispatchQueue.main.async {
                    self?.stopSpinner()
                    self?.showAlert(label:"Unable to load object information", message: error.localizedDescription)
                }
                
            case .success(let oembed):
                self?.displayOEmbed(oembed: oembed)
            default:
                ()
            }
            
        }
    }
    
    private func parseOEmbed(data: Data) -> Result<OEmbed, Error> {
        
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
        
        guard let url = URL(string: oembed.url) else {
            self.showError(error: ViewControllerErrors.invalidURL)
            return
        }
        
        DispatchQueue.main.async {
            self.scanned_meta.text = oembed.title
            self.scanned_meta.updateTextFont()
            self.scanned_meta.isHidden = false
        }
        
        DispatchQueue.main.async {
            self.loadImage(url: url)
        }
    }
    
    private func loadImage(url: URL) {
        
        self.save_button.isHidden = true
        self.clear_button.isHidden = true
        
        scanned_image.isHidden = true
        scanned_image.image = nil
        
        DispatchQueue.global().async { [weak self] in
            
            var image_data: Data?
            // var image: UIImage?
            
            do {
                image_data = try Data(contentsOf: url)
            } catch (let error) {
                
                DispatchQueue.main.async {
                    self?.stopSpinner()
                    self?.showAlert(label:"Unable to retrieve object image", message: error.localizedDescription)
                
                }
                
                return
            }
            
            guard let image = UIImage(data: image_data!) else {
                
                DispatchQueue.main.async {
                    self?.stopSpinner()
                    self?.showAlert(label:"Unable to load object image", message: "")
                }
                
                return
            }
                   
            DispatchQueue.main.async {
                
                let w = self?.scanned_image.bounds.width
                let h = self?.scanned_image.bounds.height
                
                let resized = image.resizedImage(withBounds: CGSize(width: w!, height: h!))
                
                self?.stopSpinner()
                
                self?.scanned_image.image = resized
                self?.scanned_image.isHidden = false
                
                self?.save_button.isHidden = false
                self?.clear_button.isHidden = false
            }
        }
    }
    
    
    private func addToShoebox(object_id: String, credentials: OAuthSwiftCredential){
        
        let api = CooperHewittAPI(access_token: credentials.oauthToken)
        
        let method = "cooperhewitt.shoebox.items.collectItem"
        var params = [String:String]()
        params["object_id"] = object_id
        
        func completion(rsp: Result<CooperHewittAPIResponse, Error>) {
            
            DispatchQueue.main.async {
                
                switch rsp {
                case .failure(let error):
                    
                    print("SAD")
                    switch error {
                    case is CooperHewittAPIError:
                        let api_error = error as! CooperHewittAPIError
                        self.showAlert(label: "Failed to save object", message: api_error.Message)
                    default:
                        self.showAlert(label: "Failed to save object", message: error.localizedDescription)
                    }
                    
                    return
                    
                case .success:
                    print("HAPPY")
                    self.showAlert(label: "Object saved", message: "This object has been saved to your shoebox.")
                }
            }
        }
        
        api.ExecuteMethod(method: method, params: params, completion:completion)
    }
    
    private func showError(error: Error) {
        self.app.logger.error("Error: \(error.localizedDescription)")
        self.showAlert(label:"Error", message: error.localizedDescription)
    }
    
    private func showAlert(label: String, message: String){
        
        self.app.logger.info("\(message)")
        
        let alertController = UIAlertController(
            title: label,
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func startSpinner() {
        scanning_indicator.isHidden = false
        scanning_indicator.startAnimating()
    }
    
    private func stopSpinner(){
        scanning_indicator.isHidden = true
        scanning_indicator.stopAnimating()
    }
    
    
}
