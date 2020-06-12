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

class ViewController: UIViewController, NFCNDEFReaderSessionDelegate {
    
    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCNDEFReaderSession?
    
    var oauth2: OAuthSwift?
    var credentials: OAuthSwiftCredential?
    
    var current_object = ""
    
    @IBOutlet weak var scan_button: UIButton!
    @IBOutlet weak var scanning_indicator: UIActivityIndicatorView!
    
    @IBOutlet weak var scanned_image: UIImageView!
    @IBOutlet weak var scanned_meta: UITextView!
    
    @IBOutlet weak var save_button: UIButton!
    @IBOutlet weak var clear_button: UIButton!
    
    @IBAction func save() {
        
        print("SAVE")
        
        func doSave(credentials: OAuthSwiftCredential){
            print("DO SAVE", self.current_object)
            self.addToShoebox(object_id: self.current_object, credentials: credentials)
        }
        
        getAccessToken(completion: doSave)
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
        
        let str_url = String(format: "https://collection.cooperhewitt.org/oembed/photo/?url=https://collection.cooperhewitt.org/objects/%@", object_id)
        
        guard let url = URL(string: str_url) else {
            print("SAD")
            return
        }
        
        fetchOEmbed(url: url)
        return
        
        #else
        
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
    
    func processMessage(message: NFCNDEFMessage) {
        
        let payload = message.records[0]
        let data = payload.payload
        
        let str_data = String(decoding: data, as: UTF8.self)
        let parts = str_data.split(separator: ":")
        
        if parts.count != 3 {
            print("Unknown tag")
            return
        }
        
        let scheme = parts[0]
        let host = parts[1]
        let path = parts[2]
        
        if scheme != "chsdm" {
            print("Unknown scheme")
            return
        }
        
        if host != "o" {
            print("Unknown host")
        }
        
        let object_id = String(path)
        self.current_object = object_id
        
        print("CURRENT", self.current_object)
        
        let str_url = String(format: "https://collection.cooperhewitt.org/oembed/photo/?url=https://collection.cooperhewitt.org/objects/%@", object_id)
        
        guard let url = URL(string: str_url) else {
            print("SAD")
            return
        }
        
        fetchOEmbed(url: url)
    }
    
    private func fetchOEmbed(url: URL) {
        
        DispatchQueue.global().async { [weak self] in
            
            if let data = try? Data(contentsOf: url) {
                
                let oembed_rsp = self?.parseOEmbed(data: data)
                
                switch oembed_rsp {
                case .failure(let error):
                    self?.current_object = ""
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
            print("SAD URL")
            return
        }
        
        DispatchQueue.main.async {
            self.scanned_meta.text = oembed.title
            self.scanned_meta.isHidden = false
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
    
    func getAccessToken(completion: @escaping (OAuthSwiftCredential) -> ()){
        print("AUTHORIZE")
        
        let keychain_label = "wunderkammer://org.cooperhewitt.collection/access_token"
        
        if let creds = self.credentials {
            
            if !creds.isTokenExpired() {
                print("HAVE EXISTING TOKEN")
                completion(creds)
                return
            }
        }
        
        if let data = KeychainWrapper.standard.data(forKey: keychain_label) {
            
            let decoder = JSONDecoder()
            var creds: OAuthSwiftCredential
            
            do {
                creds = try decoder.decode(OAuthSwiftCredential.self, from: data)
            } catch(let error) {
                print("SAD DECODE", error)
                return
            }
            
            if !creds.isTokenExpired() {
                print("HAVE EXISTING TOKEN")
                completion(creds)
                return
            }
        }
        
        func getStore(credentials: OAuthSwiftCredential) {
            
            let encoder = JSONEncoder()
            
            do {
                let data = try encoder.encode(credentials)
                KeychainWrapper.standard.set(data, forKey: keychain_label)
            } catch (let error) {
                    print("SAD ENCODING", error)
            }
            
            completion(credentials)
        }
        
        self.getNewAccessToken(completion: getStore)
    }
    
    private func getNewAccessToken(completion: @escaping (OAuthSwiftCredential) -> ()){
        
        print("GET NEW ACCESS TOKEN")
        
        let oauth2_auth_url = Bundle.main.object(forInfoDictionaryKey: "OAuth2AuthURL") as? String
        let oauth2_token_url = Bundle.main.object(forInfoDictionaryKey: "OAuth2TokenURL") as? String
        let oauth2_client_id = Bundle.main.object(forInfoDictionaryKey: "OAuth2ClientID") as? String
        let oauth2_client_secret = Bundle.main.object(forInfoDictionaryKey: "OAuth2ClientSecret") as? String
        let oauth2_scope = Bundle.main.object(forInfoDictionaryKey: "OAuth2Scope") as? String
        
        if oauth2_auth_url == nil || oauth2_auth_url == "" {
            //invalidConfigError(property: "OAuth2AuthURL")
            print("SAD AUTH URL")
            return
        }
        
        if oauth2_token_url == nil || oauth2_token_url == "" {
            //invalidConfigError(property: "OAuth2TokenURL")
            print("SAD TOKEN URL")
            return
        }
        
        if oauth2_client_id == nil || oauth2_client_id == "" {
            //invalidConfigError(property: "OAuth2ClientID")
            print("SAD CLIENT ID")
            return
        }
        
        if oauth2_client_secret == nil || oauth2_client_secret == "" {
            //invalidConfigError(property: "OAuth2ClientSecret")
            
            print("SAD CLIENT SECRET")
            
            // Cooper Hewitt...
            // return
        }
        
        if oauth2_scope == nil || oauth2_scope == "" {
            //invalidConfigError(property: "OAuth2AuthURL")
            print("SAD SCOPE")
            return
        }
        
        let oauth2_state = UUID().uuidString
        
        var response_type = "token"
        var allow_missing_state = false
        
        response_type = "code" // Cooper Hewitt...
        allow_missing_state = true  // Cooper Hewitt...
        
        let oauth2 = OAuth2Swift(
            consumerKey:    oauth2_client_id!,
            consumerSecret: oauth2_client_secret!,
            authorizeUrl:   oauth2_auth_url!,
            accessTokenUrl: oauth2_token_url!,
            responseType:   response_type
        )
        
        oauth2.allowMissingStateCheck = allow_missing_state
        
        // make sure we retain the oauth2 instance (I always forget this part...)
        self.oauth2 = oauth2
        
        // The URL scheme for Wallet (Passbook and Apple Pay together) is shoebox://, but that is officially an 'undocumented API' (source).
        
        oauth2.authorize(
            withCallbackURL: "wunderkammer://oauth2",
            scope: oauth2_scope!,
            state:oauth2_state
        ) { result in
            // print("RESULT", result)
            switch result {
            case .success(let (credential, _, _)):
                self.credentials = credential
                completion(credential)
            case .failure(let error):
                // https://github.com/OAuthSwift/OAuthSwift/blob/master/Sources/OAuthSwiftError.swift
                // https://github.com/OAuthSwift/OAuthSwift/wiki/Interpreting-Error-Codes
                print("SAD CALLBACK", error, error.localizedDescription)
                return
            }
        }
        
    }
    
    private func addToShoebox(object_id: String, credentials: OAuthSwiftCredential){
        
        let api = CooperHewittAPI(access_token: credentials.oauthToken)
        
        let method = "cooperhewitt.shoebox.items.collectItem"
        var params = [String:String]()
        params["object_id"] = object_id

        api.ExecuteMethod(method: method, params: params)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scanning_indicator.isHidden = true
    }
    
}
