//
//  ViewController.swift
//  wunderkammer
//
//  Created by asc on 6/9/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

import UIKit
import CoreNFC
import CoreBluetooth

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
    case debugError
}

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate, NFCNDEFReaderSessionDelegate {
    
    var enable_ble_scanning = false
    var enable_ble_broadcasting = false
    var enable_nfc_scanning = false
    
    // BLE - reading
    
    let ble_service_name = "wunderkammer"
    let ble_service_id = CBUUID(string: "7F278F93-6F26-4BE0-AB1A-6F97D2B5362A") // wunderkammer
    let ble_characterstic_id = CBUUID(string: "F65536AD-D2F3-40EE-9512-FB18B983EF86") // object
    
    var ble_manager: CBCentralManager!
    var ble_target: CBPeripheral!
    var peripheral_manager: CBPeripheralManager!
    var broadcast_service: CBMutableService!
    var broadcast_characteristic: CBMutableCharacteristic!
    
    // BLE - broadcasting
    
    let ble_broadcast_name = "\(UIDevice.current.name)'s wunderkammer"
    
    let beaconOperationsQueue = DispatchQueue(label: "beacon_operations_queue")
    let pm_option = [CBCentralManagerScanOptionAllowDuplicatesKey:false]
    
    let app = UIApplication.shared.delegate as! AppDelegate
    var opQueue = OperationQueue()
    
    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCNDEFReaderSession?
    
    var current_collection: Collection?
    var current_oembed: CollectionOEmbed?
    var current_image: UIImage?
    
    var collections = [Collection]()
    
    // these are used for looping and shuffling and are meant to
    // be offsets/pointers in to the collections array
    
    var collections_nfc = [Int]()
    var collections_ble = [Int]()
    var collections_tags = [Int]()
    
    var collections_random = [Int]()
    
    var has_nfc = false
    var has_ble = false
    
    var ble_available = false
    var ble_scanning = false
    var ble_listening = false
    let ble_timeout = 5.0
    
    var ble_known_peripherals = [UUID]()
    var ble_candidate_peripherals = [CBPeripheral]()
    
    var broadcasting = false
    
    var nfc_scanning = false
    
    var random_polling = false
    
    @IBOutlet weak var scan_button: UIButton!
    
    // PLEASE RENAME ME (see below)
    @IBOutlet weak var scanning_indicator: UIActivityIndicatorView!
    
    @IBOutlet weak var scanned_image: UIImageView!
    @IBOutlet weak var scanned_meta: UITextView!
    
    @IBOutlet weak var save_button: UIButton!
    @IBOutlet weak var clear_button: UIButton!
    @IBOutlet weak var random_button: UIButton!
    @IBOutlet weak var share_button: UIButton!
    
    @IBOutlet weak var broadcast_button: UIButton!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        if scan_button.imageView != nil {
            scan_button.imageView!.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
        
        let ble_scanning = Bundle.main.object(forInfoDictionaryKey: "EnableBluetoothScanning") as? String
        self.enable_ble_scanning = ble_scanning != nil && ble_scanning == "YES"
        
        let ble_broadcasting = Bundle.main.object(forInfoDictionaryKey: "EnableBluetoothBroadcasting") as? String
        self.enable_ble_broadcasting = ble_broadcasting != nil && ble_broadcasting == "YES"
        
        let nfc_scanning = Bundle.main.object(forInfoDictionaryKey: "EnableNFCScanning") as? String
        self.enable_nfc_scanning = nfc_scanning != nil && nfc_scanning == "YES"
        
        // please something better to load collections...
        // https://github.com/aaronland/ios-wunderkammer/issues/19
        
        let enable_sfomuseum = Bundle.main.object(forInfoDictionaryKey: "EnableSFOMuseum") as? String
        
        if enable_sfomuseum != nil && enable_sfomuseum == "YES" {
            let sfomuseum_collection = SFOMuseumCollection()
            self.collections.append(sfomuseum_collection)
        }
        
        let enable_smithsonian = Bundle.main.object(forInfoDictionaryKey: "EnableSmithsonian") as? String
        
        if enable_smithsonian != nil && enable_smithsonian == "YES" {
            
            let smithsonian_collection = SmithsonianCollection()
            
            if smithsonian_collection == nil {
                self.showAlert(label:"There was a problem configuring the application.", message: "Unable to initialize Smithsonian collection.")
            } else {
                self.collections.append(smithsonian_collection!)
            }
        }
        
        let enable_metmuseum = Bundle.main.object(forInfoDictionaryKey: "EnableMetMuseum") as? String
        
        if enable_metmuseum != nil && enable_metmuseum == "YES" {
            
            let metmuseum_collection = MetMuseumCollection()
            
            if metmuseum_collection == nil {
                self.showAlert(label:"There was a problem configuring the application.", message: "Unable to initialize Met Museum collection.")
            } else {
                self.collections.append(metmuseum_collection!)
            }
        }
        
        let enable_orthis = Bundle.main.object(forInfoDictionaryKey: "EnableOrThis") as? String
        
        if enable_orthis != nil && enable_orthis == "YES" {
            
            let orthis_collection = OrThisCollection()
            
            if orthis_collection == nil {
                self.showAlert(label:"There was a problem configuring the application.", message: "Unable to initialize OrThis collection.")
            } else {
                self.collections.append(orthis_collection!)
            }
        }
        
        let enable_cooperhewitt = Bundle.main.object(forInfoDictionaryKey: "EnableCooperHewitt") as? String
        
        if enable_cooperhewitt != nil && enable_cooperhewitt == "YES" {
            
            let result = NewOAuth2WrapperConfigFromBundle(bundle: Bundle.main, prefix: "CooperHewitt")
            
            switch result {
            case .failure(let error):
                
                self.showAlert(label:"There was a problem configuring the application.", message: error.localizedDescription)
                return
            case .success(var config):
                
                config.ResponseType = "code"
                config.AllowNullExpires = true
                config.AllowMissingState = true
                
                let wrapper = OAuth2Wrapper(config: config)
                
                wrapper.logger.logLevel = .debug
                
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
        
        // Ensure that at least one of the collections even supports NFC tags
        // Something something something geofencing something something something
        // (20200630/thisisaaronland)
        
        var nfc_enabled = false
        var random_enabled = false
        
        var idx = 0
        
        for c in self.collections {
            
            var tags = false
            
            let nfc_result = c.HasCapability(capability: CollectionCapabilities.nfcTags)
            
            if case .success(let capability) = nfc_result {
                
                if capability {
                    collections_nfc.append(idx)
                    tags = true
                }
            }
            
            let ble_result = c.HasCapability(capability: CollectionCapabilities.bleTags)
            
            if case .success(let capability) = ble_result {
                
                if capability {
                    collections_ble.append(idx)
                    tags = true
                }
            }
            
            if tags {
                collections_tags.append(idx)
            }
            
            let random_result = c.HasCapability(capability: CollectionCapabilities.randomObject)
            
            if case .success(let capability) = random_result {
                
                if capability {
                    collections_random.append(idx)
                }
            }
            
            idx += 1
        }
        
        if collections_nfc.count > 0 {
            nfc_enabled = true
        }
        
        if collections_ble.count > 0 {
            ble_manager = CBCentralManager(delegate: self, queue: nil)
            self.has_ble = true
        }
        
        if collections_random.count > 0 {
            random_enabled = true
        }
        
        if NFCNDEFReaderSession.readingAvailable && nfc_enabled {
            self.has_nfc = true
        }
        
        // has_ble is set below in centralManagerDidUpdateState
        // (20200725/straup)
        
        if self.has_nfc || self.has_ble {
            scan_button.isEnabled = true
            scan_button.isHidden = false
        }
        
        if random_enabled {
            random_button.isEnabled = true
            random_button.isHidden = false
        }
        
        if !nfc_enabled && !random_enabled {            
            self.showAlert(label:"There was a problem configuring the application.", message: "No collections implement NFC tag scanning or random objects.")
            return
        }
        
        peripheral_manager = CBPeripheralManager(delegate: self, queue: beaconOperationsQueue, options: pm_option)
        
        // read this from config file
        self.app.logger.logLevel = .debug
        
        // self.scanning_indicator.isHidden = true
        self.updateScanButtonVisibility()
    }
    
    // MARK: - Buttons
    
    @IBAction func share() {
        
        guard let oembed = self.current_oembed else {
            return
        }
        
        guard let url = URL(string: oembed.ObjectURL()) else {
            return
        }
        
        let activityViewController =
            UIActivityViewController(activityItems: [url],
                                     applicationActivities: nil)
        
        present(activityViewController, animated: true)
        
        if let popOver = activityViewController.popoverPresentationController {
            popOver.sourceView = self.view
            popOver.sourceRect = self.share_button.bounds
        }
    }
    
    @IBAction func random() {
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        self.resetCurrent()
        
        self.random_polling = true
        
        self.updateButtonsVisibility()
        self.startSpinner()
        
        let idx = self.collections_random.randomElement()!
        self.current_collection = self.collections[idx]
        
        func completion(result: Result<URL, Error>) -> () {
            
            switch result {
            
            case .failure(let error):
                
                self.random_polling = false
                
                self.updateButtonsVisibility()
                self.stopSpinner()
                
                DispatchQueue.main.async {
                    
                    self.showAlert(label:"There was problem generating the URL for a random image", message: error.localizedDescription)
                }
                
            case .success(let url):
                fetchOEmbed(url: url)
            }
        }
        
        self.current_collection?.GetRandomURL(completion: completion)
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
        
        save_button.isEnabled = false
        
        var to_complete = 1 // locally, to the wunderkammer
        var completed = 0
        
        var remote_save = false // flag used to determine copy in feedback messages
        
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
            
            if completed < to_complete {
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
                    
                    if remote_save {
                        
                        self.showAlert(label: "This object was saved remotely but there was a problem saving this object to your device.", message: error_message(error: error_local!))
                    } else {
                        
                        self.showAlert(label: "There was a problem saving this object to your device.", message: error_message(error: error_local!))
                    }
                } else {
                    
                    if remote_save {
                        self.showAlert(label: "This object has been saved.", message: "This object has been saved remotely and to your device.")
                    } else {
                        
                        self.showAlert(label: "This object has been saved.", message: "This object has been saved to your device.")
                    }
                }
                
            }
        }
        
        // check for remote saving capability and update to_complete
        // counter before we actually start saving anything
        
        let capability_result = collection.HasCapability(capability: .saveObject)
        
        switch capability_result {
        case .failure(let error):
            
            DispatchQueue.main.async {
                self.showAlert(label: "Unable to save object remotely.", message: error.localizedDescription)
            }
            
        case .success(let has_capability):
            
            if has_capability {
                
                remote_save = true
                to_complete += 1
                
                DispatchQueue.global().async {
                    
                    let result = collection.SaveObject(oembed: current_oembed, image: current_image)
                    
                    DispatchQueue.main.async {
                        
                        if case .failure(let error) = result {
                            error_local = error
                        }
                        
                        on_complete()
                    }
                }
            }
        }
        
        // save locally to the wunderkammer
        
        DispatchQueue.global().async { [weak self] in
            
            let result = self?.app.wunderkammer!.SaveObject(oembed: current_oembed, image: current_image)
            
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
        self.updateButtonsVisibility()
    }
    
    @IBAction func scanTag() {
        
        if self.ble_scanning || self.ble_listening {
            
            self.app.logger.debug("Stop BLE scanning")
            
            self.ble_scanning = false
            self.ble_listening = false
            
            if self.ble_target != nil {
                self.disconnectBLEPeripheral()
            }
            
            self.updateButtonsVisibility()
            return
        }
        
        self.app.logger.debug("Scan tag")
        
        if self.has_nfc && self.has_ble && self.ble_available {
            
            let optionMenu = UIAlertController(title: nil, message: "Choose Option", preferredStyle: .actionSheet)
            
            let nfc_action = UIAlertAction(title: "NFC", style: .default, handler: {_ in
                self.scanNFCTag()
            })
            
            let ble_action = UIAlertAction(title: "Bluetooth", style: .default, handler: { _ in
                self.scanBLETag()
            })
            
            let cancel_action = UIAlertAction(title: "Cancel", style: .cancel)
            
            optionMenu.addAction(nfc_action)
            optionMenu.addAction(ble_action)
            optionMenu.addAction(cancel_action)
            
            optionMenu.popoverPresentationController?.sourceView = self.view
            
            optionMenu.popoverPresentationController?.sourceView = self.view
            optionMenu.popoverPresentationController?.sourceRect = self.scan_button.bounds
            optionMenu.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.left
            
            self.present(optionMenu, animated: true, completion: nil)
            return
        }
        
        if self.has_nfc {
            self.scanNFCTag()
            return
        }
        
        if self.has_ble {
            self.scanBLETag()
        }
        
    }
    
    @IBAction func broadcast() {
        
        if self.broadcasting == true {
            
            self.app.logger.debug("Stop broadcasting")
            
            self.broadcast_button.isHighlighted = false
            self.broadcast_button.tintColor = .systemBlue
            
            self.broadcasting = false
            self.stopBroadcasting()
            
            return
        }
        
        self.app.logger.debug("Start broadcasting")
        
        self.broadcasting = true
        
        self.broadcast_button.isHighlighted = true
        self.broadcast_button.tintColor = .red
        
        self.startBroadcasting()
    }
    
    // MARK: - BLE Methods
    
    func bleIsEnabled(enabled: Bool) {
        
        self.app.logger.debug("Bluetooth is enabled: \(enabled)")
        
        self.ble_available = enabled
        
        self.updateButtonsVisibility()
    }
    
    // MARK: - BLE Broadcasting Methods
    
    func broadcastOEmbed(oembed: CollectionOEmbed){
        
        let uri = oembed.ObjectURI()
        
        guard let data = uri.data(using: .utf8) else {
            return
        }
        
        guard let ch = self.broadcast_characteristic else {
            return
        }
        
        self.app.logger.debug("Broadcast \(uri)")
        
        let ok = self.peripheral_manager.updateValue(data, for: ch, onSubscribedCentrals: nil)
        
        if !ok {
            self.app.logger.warning("Failed to broadcast \(uri)")
        }
    }
    
    private func startBroadcasting() {
        
        if self.peripheral_manager == nil {
            self.app.logger.warning("Unable to start broadcasting since there is no peripheral manager.")
            return
        }
        
        let ble_broadcast_service = ble_service_id // CBUUID(string: UUID().uuidString) // gallery
        let ble_broadcast_characterstic = ble_characterstic_id // CBUUID(string: UUID().uuidString) // object
        
        broadcast_characteristic = CBMutableCharacteristic(type: ble_broadcast_characterstic, properties: [.read, .notify], value: nil, permissions: [.readable])
        
        broadcast_service = CBMutableService(type: ble_broadcast_service, primary: true)
        
        broadcast_service.characteristics = [
            broadcast_characteristic
        ]
        
        peripheral_manager.add(broadcast_service)
        
        peripheral_manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [ble_broadcast_service],
            CBAdvertisementDataLocalNameKey: self.ble_broadcast_name
        ])
        
        self.app.logger.debug("Start advertising as \(self.ble_broadcast_name)")
    }
    
    private func stopBroadcasting() {
        
        if self.peripheral_manager == nil {
            return
        }
        
        if self.peripheral_manager.isAdvertising{
            self.peripheral_manager.stopAdvertising()
        }
        
        self.peripheral_manager.removeAllServices()
    }
    
    // MARK: - NFC Scanning methods
    
    func scanNFCTag() {
        
        guard NFCNDEFReaderSession.readingAvailable else {
            self.showAlert(label: "NFC scanning Not Supported", message: "This device doesn't support NFC tag scanning.")
            return
        }
        
        self.app.logger.debug("Starting NFC session")
        self.clear()
        
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the item to learn more about it."
        session?.begin()
        ()
        
        self.updateButtonsVisibility()
    }
    
    // MARK: - BLE Scanning Methods
    
    func scanBLETag() {
        
        if !self.ble_available {
            self.showAlert(label: "BLE scanning Not Supported", message: "This device doesn't support Bluetooth Low Energy tag scanning.")
            return
        }
        
        if ble_scanning {
            self.app.logger.debug("Already scanning")
            return
        }
        
        self.clear()
        // Needs an NFC style popover dialog with a cancel button
        
        self.startBLEScanning()
    }
    
    func startBLEScanning() {
        
        self.app.logger.debug("Start BLE scanning")
        
        self.startSpinner()
        self.ble_scanning  = true
        
        self.updateButtonsVisibility()
        
        /*
         if self.ble_known_peripherals.count >= 1 {
         
         let known = self.ble_manager.retrievePeripherals(withIdentifiers: self.ble_known_peripherals)
         
         // Choose peripheral? Probably, imagine a space with multiple
         // wunderkammer devices...
         
         switch known.count {
         case 0:
         self.app.logger.debug("No known peripherals")
         case 1:
         
         self.app.logger.debug("Found peripheral, reconnecting to \(known[0].identifier).")
         
         self.stopBLEScanning()
         self.connectBLEPeripheral(peripheral: known[0])
         return
         
         default:
         self.stopBLEScanning()
         self.chooseBLEPeripheral(peripherals: known)
         return
         }
         
         }
         */
        
        self.ble_candidate_peripherals = [CBPeripheral]()
        
        self.ble_manager.scanForPeripherals(withServices: [self.ble_service_id], options: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + ble_timeout) {
            
            if !self.ble_scanning {
                return
            }
            
            self.app.logger.debug("BLE scanning timeout")
            self.stopBLEScanning()
            
            switch self.ble_candidate_peripherals.count {
            case 0:
                
                DispatchQueue.main.async {
                    self.showAlert(label: "There was a problem finding any tags.", message: "Unable to find any devices to connect to.")
                }
                
                self.updateButtonsVisibility()
                
            case 1:
                self.connectBLEPeripheral(peripheral: self.ble_candidate_peripherals[0])
            default:
                self.chooseBLEPeripheral(peripherals: self.ble_candidate_peripherals)
            }
            
        }
        
    }
    
    func stopBLEScanning() {
        
        self.app.logger.debug("Stop BLE scanning")
        
        self.ble_manager.stopScan()
        self.ble_scanning = false
        self.stopSpinner()
    }
    
    func chooseBLEPeripheral(peripherals: [CBPeripheral]) {
        
        let optionMenu = UIAlertController(title: nil, message: "Choose Device to Connect to", preferredStyle: .actionSheet)
        
        for p in peripherals {
            let label = "\(String(describing: p.name)) (\(p.identifier))"
            print(label)
            let action = UIAlertAction(title: label, style: .default, handler: { _ in
                print(p, label)
                self.connectBLEPeripheral(peripheral: p)
            })
            optionMenu.addAction(action)
        }
        
        let action = UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            return
        })
        
        optionMenu.addAction(action)
        
        optionMenu.popoverPresentationController?.sourceView = self.view
        optionMenu.popoverPresentationController?.sourceRect = self.scan_button.bounds
        optionMenu.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.left
        
        self.present(optionMenu, animated: true, completion: nil)
        return
    }
    
    func connectBLEPeripheral(peripheral: CBPeripheral) {
        self.ble_target = peripheral
        self.ble_target.delegate = self
        self.ble_manager.connect(self.ble_target)
    }
    
    func disconnectBLEPeripheral() {
        
        self.ble_manager.cancelPeripheralConnection(self.ble_target)
        self.ble_target = nil
        self.ble_listening = false
        
        self.updateButtonsVisibility()
    }
    
    // MARK: - CBPeripheralManager Methods
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        switch peripheral.state {
        case .unknown:
            print("peripheral.state is .unknown")
        case .resetting:
            print("peripheral.state is .resetting")
            self.bleIsEnabled(enabled: false)
            self.stopBroadcasting()
        case .unsupported:
            print("peripheral.state is .unsupported")
            self.bleIsEnabled(enabled: false)
            self.stopBroadcasting()
        case .unauthorized:
            print("peripheral.state is .unauthorized")
            self.bleIsEnabled(enabled: false)
            self.stopBroadcasting()
        case .poweredOff:
            print("peripheral.state is .off")
            self.bleIsEnabled(enabled: false)
            self.stopBroadcasting()
        case .poweredOn:
            print("peripheral.state is .on")
            self.bleIsEnabled(enabled: true)
        @unknown default:
            print("WHAT IS", peripheral.state)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        
        if request.characteristic.uuid != ble_characterstic_id {
            return
        }
        
        guard let current = self.current_oembed else {
            return
        }
        
        let object_uri = current.ObjectURI()
        
        guard let data = object_uri.data(using: .utf8) else {
            return
        }
        
        request.value = data
        
        self.peripheral_manager.respond(to: request, withResult: .success)
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        
        if error != nil {
            self.app.logger.warning("\(String(describing: error))")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        
        if error != nil {
            self.app.logger.warning("\(String(describing: error))")
        }
    }
    
    // MARK: - CBCentralManagerDelegate Methods
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
            self.bleIsEnabled(enabled: false)
        case .unsupported:
            print("central.state is .unsupported")
            self.bleIsEnabled(enabled: false)
        case .unauthorized:
            print("central.state is .unauthorized")
            self.bleIsEnabled(enabled: false)
        case .poweredOff:
            print("central.state is .off")
            self.bleIsEnabled(enabled: false)
        case .poweredOn:
            print("central.state is .on")
            self.bleIsEnabled(enabled: true)
        @unknown default:
            print("WHAT IS", central.state)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if !self.ble_candidate_peripherals.contains(peripheral){
            self.ble_candidate_peripherals.append(peripheral)
        }
        
        return
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.app.logger.debug("Connected to '\(ble_service_name)'")
        
        let uuid = peripheral.identifier
        
        if !self.ble_known_peripherals.contains(uuid){
            self.ble_known_peripherals.append(uuid)
        }
        
        self.ble_target.discoverServices([ble_service_id])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        if error == nil {
            return
        }
        
        self.app.logger.warning("Failed to connect to '\(String(describing: peripheral.name))', \(String(describing: error))")
        
        DispatchQueue.main.async {
            self.showAlert(label: "Failed to connect to Bluetooth tag", message: error!.localizedDescription)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        // 2020-07-29T12:16:27-0700 warning: Failed to disconnect from 'Optional("SD-931")', Optional(Error Domain=CBErrorDomain Code=7 "The specified device has disconnected from us." UserInfo={NSLocalizedDescription=The specified device has disconnected from us.})
        
        if error != nil {
            self.app.logger.warning("Failed to disconnect from '\(String(describing: peripheral.name))', \(String(describing: error))")
        }
        
        self.ble_listening = false
        self.updateButtonsVisibility()
    }
    
    // MARK: - CBPeripheralDelegate Methods
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if error != nil {
            self.app.logger.warning("Failed to discover services for '\(ble_service_name)': \(String(describing: error))")
            
            DispatchQueue.main.async {
                self.showAlert(label: "Failed to read Bluetooth tag", message: error!.localizedDescription)
            }
            
            return
        }
        
        if let services = peripheral.services as [CBService]?{
            
            for service in services{
                peripheral.discoverCharacteristics([ble_characterstic_id], for: service)
            }
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if error != nil {
            self.app.logger.warning("Failed to discover characteristics for '\(ble_service_name)': \(String(describing: error))")
            
            DispatchQueue.main.async {
                self.showAlert(label: "Failed to read Bluetooth tag", message: error!.localizedDescription)
            }
            
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            
            if characteristic.properties.contains(.read) {
                
                // When you attempt to read the value of a characteristic, the peripheral calls the peripheral:didUpdateValueForCharacteristic:error: method of its delegate object to retrieve the value. If the value is successfully retrieved, you can access it through the characteristic’s value property,
                peripheral.readValue(for: characteristic)
            }
            
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
                self.ble_listening = true
                self.app.logger.debug("Listening for notifications from characteristic \(characteristic.uuid)")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        guard let data = characteristic.value else {
            return
        }
        
        let tag = String(decoding: data, as: UTF8.self)
        self.app.logger.debug("Received BLE message '\(tag)'")
        
        self.processTag(tag: tag)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        for s in invalidatedServices {
            self.app.logger.warning("Lost connection to \(s.uuid)")
        }
        
        // This is probably not as sophisticated a check as it should be
        
        self.disconnectBLEPeripheral()
        
        DispatchQueue.main.async {
            self.showAlert(label:"No longer able to read tags.", message: "The Bluetooth connection was interrupted.")
        }
    }
    
    // MARK: - NFCNDEFReaderSessionDelegate
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        self.app.logger.debug("NFC reader session is active")
        self.nfc_scanning = true
        
        self.updateScanButtonVisibility()
        self.updateRandomButtonVisibility()
        self.updateClearButtonVisibility()
    }
    
    /// - Tag: processingTagData
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        
        self.app.logger.debug("Did detect message")
        
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
                        
                        self.app.logger.debug("Found 1 NDEF message")
                        statusMessage = "Found 1 NDEF message"
                        self.processNDEFMessage(message: message!)
                    }
                    
                    session.alertMessage = statusMessage
                    session.invalidate()
                })
            })
        })
    }
    
    /// - Tag: endScanning
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        
        self.app.logger.debug("NFC reader session is ended")
        self.nfc_scanning = false
        
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
        
        self.updateButtonsVisibility()
    }
    
    private func uriFromMessage(message: NFCNDEFMessage) -> Result<String, Error> {
        
        var uri: String?
        
        let payload = message.records[0]
        
        // things written by ios-nfc-tagwriter
        
        let text_payload = payload.wellKnownTypeTextPayload()
        
        if text_payload.0 != nil {
            uri = text_payload.0
            return .success(uri!)
        }
        
        // TO DO: handle payload.wellKnownTypeURIPayload()
        
        // things written by Cooper Hewitt tag-writer
        
        let data = payload.payload
        uri = String(decoding: data, as: UTF8.self)
        
        return .success(uri!)
    }
    
    // MARK: - Tag processing methods
    
    private func processNDEFMessage(message: NFCNDEFMessage) {
        
        let uri_result = uriFromMessage(message: message)
        
        switch uri_result {
        case .failure(let error):
            
            self.showAlert(label:"Failed to read tag", message:error.localizedDescription)
            return
        case .success(let uri):
            return self.processTag(tag: uri)
        }
        
    }
    
    private func processTag(tag: String) {
        
        self.app.logger.debug("Process message \(String(describing: tag))")
        
        var possible_urls = [String]()
        var possible_collections = [Collection]()
        
        for idx in self.collections_tags {
            
            let c = self.collections[idx]
            
            var object_id: String?
            var collection: String?
            
            let template_rsp = c.NFCTagTemplate()
            
            switch template_rsp {
            case .failure(let error):
                
                switch error {
                case CollectionErrors.notImplemented:
                    continue
                default:
                    self.showAlert(label:"Failed to retrieve tag template", message:error.localizedDescription)
                    return
                }
                
            case .success(let template):
                
                guard let variables = template.extract(tag) else {
                    continue
                }
                
                guard let id = variables["objectid"] else {
                    continue
                }
                
                object_id = id
                
                if variables["collection"] != nil {
                    collection = variables["collection"]
                }
                
                self.app.logger.debug("Scanned object \(id)")
            }
            
            let url_rsp = c.ObjectURLTemplate()
            
            switch url_rsp {
            
            case .failure(let error):
                
                DispatchQueue.main.async {
                    self.showAlert(label:"Failed to retrieve tag URL template", message:error.localizedDescription)
                }
                
                return
                
            case .success(let template):
                
                var args = [String:Any]()
                args["objectid"] = object_id!
                
                let str_url = template.expand(args)
                
                if str_url == "" {
                    self.app.logger.warning("Tag URL template returns an empty string")
                    continue
                }
                
                possible_urls.append(str_url)
                possible_collections.append(c)
                
                self.app.logger.debug("Object ID \(object_id!) resolves as \(str_url)")
            }
        }
        
        if possible_urls.count == 0 {
            
            if self.ble_listening {
                
                self.app.logger.debug("Disconnect BLE peripheral")
                self.disconnectBLEPeripheral()
                
                DispatchQueue.main.async {
                    self.showAlert(label:"Failed to read tag, no possible URLs", message:"Unrecognized tag. Disconnecting Bluetooth connection.")
                }
                
            } else {
                
                DispatchQueue.main.async {
                    self.showAlert(label:"Failed to read tag, no possible URLs", message:"Unrecognized tag")
                }
            }
            
            return
        }
        
        // TO DO: dialog to prompt user to choose
        
        if possible_urls.count > 1 {
            DispatchQueue.main.async {
                self.showAlert(label:"Failed to read tag", message:"Unable to determine tag source (multiple choices)")
            }
            return
        }
        
        let object_url = possible_urls[0]
        self.current_collection = possible_collections[0]
        
        var oembed_url = ""
        
        let result = self.current_collection!.OEmbedURLTemplate()
        
        switch result {
        case .failure(let error):
            DispatchQueue.main.async {
                self.showAlert(label:"Failed to handle tag", message:error.localizedDescription)
            }
            return
        case .success(let t):
            oembed_url = t.expand(["url": object_url])
        }
        
        if oembed_url == "" {
            self.showAlert(label:"Failed to handle tag", message:"Unable to resolve URL")
            return
        }
        
        self.app.logger.debug("OEmbed URL resolves as \(oembed_url)")
        
        guard let url = URL(string: oembed_url) else {
            self.showError(error: ViewControllerErrors.invalidURL)
            return
        }
        
        fetchOEmbed(url: url)
    }
    
    // MARK:- OEmbed methods
    
    private func fetchOEmbed(url: URL) {
        
        guard let current_collection = self.current_collection else {
            DispatchQueue.main.async {
                self.showAlert(label:"Unable to fetch object information", message: "Unable to determine current collection")
            }
            return
        }
        
        self.app.logger.debug("Fetch OEmbed URL \(url.absoluteString)")
        
        DispatchQueue.global().async { [weak self] in
            
            let result = current_collection.GetOEmbed(url: url)
            
            switch result {
            case .failure(let error):
                
                self?.random_polling = false
                
                self?.updateButtonsVisibility()
                
                DispatchQueue.main.async {
                    self?.showAlert(label:"Unable to load OEmbed information", message: error.localizedDescription)
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
        let col = oembed.Collection()
        
        self.app.logger.debug("Display \(title) (\(col))")
        
        guard let url = URL(string: image_url) else {
            self.showError(error: ViewControllerErrors.invalidURL)
            return
        }
        
        DispatchQueue.main.async {
            self.scanned_meta.text = "\(title) (\(col))"
            self.scanned_meta.updateTextFont()
            self.scanned_meta.isHidden = false
        }
        
        DispatchQueue.main.async {
            self.loadImage(url: url)
        }
        
        self.broadcastOEmbed(oembed: oembed)
    }
    
    // MARK: - Image methods
    
    private func loadImage(url: URL) {
        
        self.app.logger.debug("Load image \(url.absoluteString)")
        
        self.save_button.isHidden = true
        self.clear_button.isHidden = true
        
        scanned_image.isHidden = true
        scanned_image.image = nil
        
        DispatchQueue.global().async { [weak self] in
            
            var image_data: Data?
            
            do {
                image_data = try Data(contentsOf: url)
            } catch (let error) {
                
                self?.random_polling = false
                self?.updateButtonsVisibility()
                
                DispatchQueue.main.async {
                    self?.showAlert(label:"Unable to retrieve object image", message: error.localizedDescription)
                }
                
                return
            }
            
            guard let image = UIImage(data: image_data!) else {
                
                self?.random_polling = false
                self?.updateButtonsVisibility()
                
                DispatchQueue.main.async {
                    self?.showAlert(label:"Unable to load object image", message: "")
                }
                
                return
            }
            
            self?.current_image = image
            
            DispatchQueue.main.async {
                
                let w = self?.scanned_image.bounds.width
                let h = self?.scanned_image.bounds.height
                
                let resized = image.resizedImage(withBounds: CGSize(width: w!, height: h!))
                
                let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self?.imageTapped))
                
                self?.scanned_image.isUserInteractionEnabled = true
                self?.scanned_image.addGestureRecognizer(tapGestureRecognizer)
                
                self?.scanned_image.image = resized
                self?.scanned_image.isHidden = false
                
                // self?.scanned_image.enableZoom()
                
                self?.random_polling = false
                self?.updateButtonsVisibility()
            }
        }
    }
    
    @objc private func imageTapped() {
        
        guard let oembed = self.current_oembed else {
            return
        }
        
        let str_url = oembed.ObjectURL()
        
        guard let url = URL(string: str_url) else {
            return
        }
        
        UIApplication.shared.open(url)
    }
    
    // MARK: - Alerts
    
    private func showError(error: Error) {
        self.showAlert(label:"Error", message: error.localizedDescription)
    }
    
    private func showAlert(label: String, message: String){
        
        // TO DO: vibrate
        // https://developer.apple.com/documentation/uikit/uinotificationfeedbackgenerator/2369826-notificationoccurred
        
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
    
    // MARK: - Interface methods
    
    func updateButtonsVisibility() {
        
        self.updateScanButtonVisibility()
        self.updateBroadcastButtonVisibility()
        
        self.updateClearButtonVisibility()
        self.updateRandomButtonVisibility()
        
        self.updateShareButtonVisibility()
        self.updateSaveButtonVisibility()
        
        self.updatePollingIndicator()
    }
    
    func updateScanButtonVisibility() {
        
        if !self.enable_nfc_scanning && !self.enable_ble_scanning {
            
            DispatchQueue.main.async {
                self.scan_button.isHidden = true
            }
            
            return
        }
        
        DispatchQueue.main.async {
            self.scan_button.isHidden = false
        }
        
        if !self.has_nfc && !self.has_ble {
            
            DispatchQueue.main.async {
                self.scan_button.isEnabled = false
            }
            
            return
        }
        
        if !self.has_nfc && self.has_ble && !self.ble_available {
            
            DispatchQueue.main.async {
                self.scan_button.isEnabled = false
            }
            
            return
        }
        
        if self.random_polling {
            
            DispatchQueue.main.async {
                self.scan_button.isEnabled = false
            }
            
            return
        }
        
        DispatchQueue.main.async {
            
            self.scan_button.isEnabled = true
            
            if self.ble_scanning || self.ble_listening || self.nfc_scanning {
                self.scan_button.tintColor = .red
            } else {
                self.scan_button.tintColor = .systemBlue
            }
        }
        
        return
    }
    
    func updateRandomButtonVisibility() {
        
        if self.ble_scanning || self.ble_listening || self.nfc_scanning {
            
            DispatchQueue.main.async {
                self.random_button.isEnabled = false
            }
            
            return
        }
        
        if self.random_polling {
            
            DispatchQueue.main.async {
                self.random_button.isEnabled = false
            }
            
            return
        }
        
        DispatchQueue.main.async {
            self.random_button.isEnabled = true
        }
        
        return
    }
    
    func updateClearButtonVisibility() {
        
        if self.current_image == nil {
            
            DispatchQueue.main.async {
                self.clear_button.isHidden = true
            }
            
            return
        }
        
        DispatchQueue.main.async {
            self.clear_button.isHidden = false
        }
        
        if self.ble_scanning || self.ble_listening || self.nfc_scanning {
            
            DispatchQueue.main.async {
                self.clear_button.isEnabled = false
            }
            
            return
        }
        
        if self.random_polling {
            
            DispatchQueue.main.async {
                self.clear_button.isEnabled = false
            }
            
            return
        }
        
        DispatchQueue.main.async {
            self.clear_button.isEnabled = true
        }
        
        return
    }
    
    func updateShareButtonVisibility() {
        
        if self.current_image == nil {
            
            DispatchQueue.main.async {
                self.share_button.isHidden = true
            }
            
            return
        }
        
        DispatchQueue.main.async {
            self.share_button.isHidden = false
        }
        
        if self.random_polling {
            
            DispatchQueue.main.async {
                self.share_button.isEnabled = false
            }
            
            return
        }
        
        DispatchQueue.main.async {
            self.share_button.isEnabled = true
        }
    }
    
    func updateSaveButtonVisibility() {
        
        if self.current_image == nil {
            
            DispatchQueue.main.async {
                self.save_button.isHidden = true
            }
            
            return
        }
        
        DispatchQueue.main.async {
            self.save_button.isHidden = false
        }
        
        if self.random_polling {
            
            DispatchQueue.main.async {
                self.save_button.isEnabled = false
            }
            
            return
        }
        
        DispatchQueue.main.async {
            self.save_button.isEnabled = true
        }
    }
    
    func updateBroadcastButtonVisibility() {
        
        if !self.enable_ble_broadcasting {
            
            DispatchQueue.main.async {
                self.broadcast_button.isHidden = true
            }
            
            return
        }
        
        DispatchQueue.main.async {
            self.broadcast_button.isHidden = false
        }
        
        if !self.ble_available {
            
            DispatchQueue.main.async {
                self.broadcast_button.isEnabled = false
            }
            
            return
        }
        
        DispatchQueue.main.async {
            self.broadcast_button.isEnabled = true
            
            if self.broadcasting {
                self.broadcast_button.tintColor = .red
            } else {
                self.broadcast_button.tintColor = .systemBlue
            }
        }
        
    }
    
    func updatePollingIndicator() {
        
        DispatchQueue.main.async {
            if self.random_polling || self.ble_scanning {
                self.scanning_indicator.isHidden = false
            } else {
                self.scanning_indicator.isHidden = true
            }
        }
    }
    
    // These are poorly named and are really "waiting for an image to load"
    // indictators
    
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
        
        DispatchQueue.main.async {
            self.scanned_meta.text = ""
            self.scanned_image.image = nil
        }
    }
    
}
