//
//  ViewController.swift
//  wunderkammer
//
//  Created by asc on 6/9/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import UIKit
import CoreNFC
import OAuthSwift
import OAuth2Wrapper
import CooperHewittAPI

enum ViewControllerErrors : Error {
    case tagUnknownURI
    case tagUnknownScheme
    case tagUnknownHost
    case invalidURL
    case wunderkammerMissingDatabase
    case wunderkammerMissingObject
    case wunderkammerMissingOEmbed
    case wunderkammerMissingImage
    case wunderkammerMissingDataURL
    case debugError
}

class ViewController: UIViewController, NFCNDEFReaderSessionDelegate {
    
    let app = UIApplication.shared.delegate as! AppDelegate
    var opQueue = OperationQueue()
    
    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCNDEFReaderSession?
    
    var current_collection: Collection?
    var current_oembed: CollectionOEmbed?
    var current_image: UIImage?
    
    var collections = [Collection]()
    
    var is_simulation = false
    
    @IBOutlet weak var nfc_indicator: UIActivityIndicatorView!
    
    @IBOutlet weak var scan_button: UIButton!
    @IBOutlet weak var scanning_indicator: UIActivityIndicatorView!
    
    @IBOutlet weak var scanned_image: UIImageView!
    @IBOutlet weak var scanned_meta: UITextView!
    
    @IBOutlet weak var save_button: UIButton!
    @IBOutlet weak var clear_button: UIButton!
    
    @IBOutlet weak var random_button: UIButton!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        #if targetEnvironment(simulator)
        is_simulation  = true
        #elseif os(OSX)
        // is_simulation  = true
        #elseif os(iOS)
        #if targetEnvironment(macCatalyst)
        // is_simulation  = true
        #endif
        #else
        #endif
        
        // why is this necessary? why don't the little show/hide buttons in
        // Main.storyboard controls work? (20200618/thisisaaronland)
        
        nfc_indicator.isHidden = true
        scanning_indicator.isHidden = true // TO DO: RENAME ME TO WAITING INDICATOR OR SOMETHING
        
        if !NFCNDEFReaderSession.readingAvailable {
            
            if !is_simulation {
                scan_button.isEnabled = false
                scan_button.isHidden = true
            }
        }
        
        let enable_sfomuseum = Bundle.main.object(forInfoDictionaryKey: "EnableSFOMuseum") as? String
        
        if enable_sfomuseum != nil && enable_sfomuseum == "YES" {
            let sfomuseum_collection = SFOMuseumCollection()
            self.collections.append(sfomuseum_collection)
        }
        
        let enable_cooperhewitt = Bundle.main.object(forInfoDictionaryKey: "EnableCooperHewitt") as? String
        
        if enable_cooperhewitt != nil && enable_cooperhewitt == "YES" {
            
            let result = NewOAuth2WrapperConfigFromBundle(bundle: Bundle.main, prefix: "CooperHewitt")
            
            switch result {
            case .failure(let error):
                
                scan_button.isEnabled = false
                random_button.isEnabled = false
                
                self.showAlert(label:"There was a problem configuring the application.", message: error.localizedDescription)
                return
            case .success(var config):
                
                config.ResponseType = "code"
                config.AllowNullExpires = true
                config.AllowMissingState = true
                
                let wrapper = OAuth2Wrapper(config: config)
                
                wrapper.logger.logLevel = .debug
                
                if is_simulation {
                    app.logger.logLevel = .debug
                    wrapper.logger.logLevel = .debug
                    app.logger.debug("Running in simulator environment.")
                }
                
                guard let cooperhewitt_collection = CooperHewittCollection(oauth2_wrapper: wrapper) else {
                    self.showAlert(label:"There was a problem configuring the application.", message: "Unable to initialize Cooper Hewitt collection.")
                    return
                }
                
                
                self.collections.append(cooperhewitt_collection)
            }
            
        }
        
        if self.collections.count == 0 {            
            self.showAlert(label:"There was a problem configuring the application.", message: "No collections have been enabled")
            return
        }
    }
    
    @IBAction func random() {
        
        self.resetCurrent()
        
        self.random_button.isEnabled = false
        self.startSpinner()
        
        self.current_collection = self.collections.randomElement()!
        
        func completion(result: Result<URL, Error>) -> () {
            
            switch result {
            
            case .failure(let error):
                
                DispatchQueue.main.async {
                    self.random_button.isEnabled = true
                    self.stopSpinner()
                    
                    self.showAlert(label:"There was problem generating the URL for a random image", message: error.localizedDescription)
                }
            case .success(let url):
                fetchOEmbed(url: url)
            }
        }
        
        let result = self.current_collection?.GetRandom(completion: completion)
    }
    
    @IBAction func save() {
        
        guard let collection = self.current_collection else {
            self.showAlert(label:"There was problem saving this object", message: "Unable to determine current collection.")
            return
        }
        
        guard let current_oembed = self.current_oembed else {
            self.showAlert(label:"There was problem saving this object", message: "Unable to determine current object data.")
            return
        }
        
        guard let current_image = self.current_image else {
            self.showAlert(label:"There was problem saving this object", message: "Unable to determine current object image.")
            return
        }
        
        guard let data_url = current_image.dataURL() else {
            self.showAlert(label:"There was problem saving this object", message: ViewControllerErrors.wunderkammerMissingDataURL.localizedDescription)
            return
        }
        
        let obj = CollectionObject(
            ID: current_oembed.ObjectID(),
            URL: current_oembed.ObjectURL(),
            Image: data_url
        )
        
        save_button.isEnabled = false
        var completed = 0
        
        var error_local: Error?
        var error_remote: Error?
        
        func error_message(error: Error) -> String {
            
            switch error {
            case is CooperHewittAPIError:
                let api_error = error as! CooperHewittAPIError
                return api_error.Message
            default:
                return error.localizedDescription
            }
        }
        
        func on_complete() {
            
            completed += 1
            
            if completed < 2 {
                return
            }
            
            DispatchQueue.main.async {
                
                self.save_button.isEnabled = true
                
                if error_local != nil && error_remote != nil {
                    
                    let message = String(format:"%@ (local) %@ (remote)", error_message(error: error_local!), error_message(error: error_remote!))
                    
                    self.showAlert(label: "There were multiple problem saving this object remotely.", message: message)
                    
                } else if error_remote != nil {
                    
                    self.showAlert(label: "This object was saved to your device but there was a problem saving this object remotely.", message: error_message(error: error_remote!))
                    
                } else if error_local != nil {
                    
                    self.showAlert(label: "This object was saved remotely but there was a problem saving this object to your device.", message: error_message(error: error_local!))
                    
                } else {
                    self.showAlert(label: "This object has been saved.", message: "This object has been saved locally and remotely")
                }
                
            }
        }
        
        DispatchQueue.global().async { [weak self] in
            
            let result = self?.app.wunderkammer!.SaveObject(object: obj)
            
            DispatchQueue.main.async {
                
                if case .failure(let error) = result {
                    error_local = error
                }
                
                on_complete()
            }
        }
        
        DispatchQueue.global().async {
            
            let result = collection.SaveObject(object:obj)
            
            DispatchQueue.main.async {
                
                if case .failure(let error) = result {
                    error_local = error
                }
                
                on_complete()
            }
        }
        
    }
    
    
    @IBAction func clear() {
        
        self.resetCurrent()
        
        self.scanned_image.image = nil
        self.scanned_image.isHidden = true
        
        self.scanned_meta.text = ""
        self.scanned_meta.isHidden = true
        
        self.save_button.isHidden = true
        self.clear_button.isHidden = true
    }
    
    @IBAction func scanTag() {
        
        self.app.logger.debug("Scan tag")
        
        guard NFCNDEFReaderSession.readingAvailable else {
            
            self.showAlert(label: "Scanning Not Supported", message: "This device doesn't support tag scanning.")
            return
        }
        
        self.app.logger.debug("Starting NFC session")
        
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the item to learn more about it."
        session?.begin()
        ()
        
        DispatchQueue.main.async {
            self.nfc_indicator.isHidden = false
            self.nfc_indicator.startAnimating()
        }
        
    }
    
    // MARK: - NFCNDEFReaderSessionDelegate
    
    /// - Tag: processingTagData
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        
        self.app.logger.debug("Did detect message")
        
        DispatchQueue.main.async {
            self.detectedMessages.append(contentsOf: messages)
        }
    }
    
    /// - Tag: processingNDEFTag
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        
        DispatchQueue.main.async {
            self.nfc_indicator.isHidden = true
            self.nfc_indicator.stopAnimating()
        }
        
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
                        
                        self.app.logger.debug("Found 1 NDEF message")
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
        
        DispatchQueue.main.async {
            self.nfc_indicator.isHidden = true
            self.nfc_indicator.stopAnimating()
        }
        
        // Check the invalidation reason from the returned error.
        if let readerError = error as? NFCReaderError {
            // Show an alert when the invalidation reason is not because of a
            // successful read during a single-tag read session, or because the
            // user canceled a multiple-tag read session from the UI or
            // programmatically using the invalidate method call.
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
                
                DispatchQueue.main.async {
                    self.showAlert(label:"There was a problem reading tag", message: error.localizedDescription)
                }
            }
        }
        
        // To read new tags, a new session instance is required.
        self.session = nil
        
    }
    
    private func processMessage(message: NFCNDEFMessage) {
        
        // TBD... WHERE ARE PREFIXES -> COLLECTIONS REGISTERED...
        
        self.app.logger.debug("Process message")
        
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
        
        self.app.logger.debug("Scanned object \(object_id)")
        
        let str_url = String(format: "https://collection.cooperhewitt.org/oembed/photo/?url=https://collection.cooperhewitt.org/objects/%@", object_id)
        
        guard let url = URL(string: str_url) else {
            self.showError(error: ViewControllerErrors.invalidURL)
            return
        }
        
        fetchOEmbed(url: url)
    }
    
    private func fetchOEmbed(url: URL) {
        
        guard let current_collection = self.current_collection else {
            DispatchQueue.main.async {
                self.showAlert(label:"Unable to fetch object information", message: "Unable to determine current collection")
            }
            return
        }
        
        DispatchQueue.main.async {
            self.startSpinner()
        }
        
        DispatchQueue.global().async { [weak self] in
            
            DispatchQueue.main.async {
                self?.random_button.isEnabled = true
            }
            
            let result = current_collection.GetOEmbed(url: url)
            
            switch result {
            case .failure(let error):
                
                self?.resetCurrent()
                
                DispatchQueue.main.async {
                    self?.stopSpinner()
                    self?.showAlert(label:"Unable to load object information", message: error.localizedDescription)
                }
                
            case .success(let oembed_response):
                self?.current_oembed = oembed_response
                self?.displayOEmbed(oembed: oembed_response)
            }
            
        }
    }
    
    private func displayOEmbed(oembed: CollectionOEmbed) {
        
        let image_url = oembed.ImageURL()
        let title = oembed.ObjectTitle()
        
        guard let url = URL(string: image_url) else {
            self.showError(error: ViewControllerErrors.invalidURL)
            return
        }
        
        DispatchQueue.main.async {
            self.scanned_meta.text = title
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
                    self?.resetCurrent()
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
            
            self?.current_image = image
            
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
    
    private func showError(error: Error) {
        self.showAlert(label:"Error", message: error.localizedDescription)
    }
    
    private func showAlert(label: String, message: String){
        
        self.app.logger.debug("Show alert \(label): \(message)")
        
        let alertController = UIAlertController(
            title: label,
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.opQueue.addOperation {
            OperationQueue.main.addOperation({
                self.present(alertController, animated: true, completion: nil)
            })
        }
    }
    
    private func startSpinner() {
        scanning_indicator.isHidden = false
        scanning_indicator.startAnimating()
    }
    
    private func stopSpinner(){
        scanning_indicator.isHidden = true
        scanning_indicator.stopAnimating()
    }
    
    private func resetCurrent(){
        
        self.current_collection = nil
        self.current_image = nil
        self.current_oembed = nil
    }
    
}
