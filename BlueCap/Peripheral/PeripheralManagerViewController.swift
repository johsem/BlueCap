//
//  PeripheralManagerViewController.swift
//  BlueCapUI
//
//  Created by Troy Stribling on 6/5/14.
//  Copyright (c) 2014 gnos.us. All rights reserved.
//

import UIKit
import BlueCapKit
import CoreBluetooth

class PeripheralManagerViewController : UITableViewController, UITextFieldDelegate {
    
    struct MainStoryboard {
        static let peripheralManagerServicesSegue = "PeripheralManagerServices"
    }
    
    @IBOutlet var nameTextField         : UITextField!
    @IBOutlet var advertiseButton       : UIButton!
    @IBOutlet var servicesLable         : UILabel!
    
    var peripheral : String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let peripheral = self.peripheral {
            self.nameTextField.text = peripheral
        }
        PeripheralManager.sharedInstance().powerOn({
                self.setPeripheralManagerServices()
            }, afterPowerOff:{
                self.setUIState()
        })
    }
    
    override func viewWillAppear(animated:Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.title = "Peripheral"
    }

    override func viewWillDisappear(animated: Bool) {
        self.navigationItem.title = ""
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepareForSegue(segue:UIStoryboardSegue!, sender:AnyObject!) {
        if segue.identifier == MainStoryboard.peripheralManagerServicesSegue {
            let viewController = segue.destinationViewController as PeripheralManagerServicesViewController
            viewController.peripheral = self.peripheral
        }
    }
    
    override func shouldPerformSegueWithIdentifier(identifier:String!, sender:AnyObject!) -> Bool {
        if identifier == MainStoryboard.peripheralManagerServicesSegue {
            if let peripheral = self.peripheral {
                let manager = PeripheralManager.sharedInstance()
                return manager.isPoweredOn && !manager.isAdvertising
            } else {
                return false
            }
        } else {
            return true
        }
    }

    @IBAction func toggleAdvertise(sender:AnyObject) {
        let manager = PeripheralManager.sharedInstance()
        if manager.isAdvertising {
            manager.stopAdvertising(){
                self.setUIState()
            }
        } else {
            if let peripheral = self.peripheral {
                manager.startAdvertising(peripheral, afterAdvertisingStartedSuccess:{
                        self.setUIState()
                    }, afterAdvertisingStartFailed:{(error) in
                        self.setUIState()
                        self.presentViewController(UIAlertController.alertOnError(error), animated:true, completion:nil)
                    })
            }
        }
    }

    func setPeripheralManagerServices() {
        let peripheralManager = PeripheralManager.sharedInstance()
        let profileManager = ProfileManager.sharedInstance()
        peripheralManager.removeAllServices() {
            if let peripheral = self.peripheral {
                self.loadPeripheralServicesFromConfig()
            } else {
                self.setUIState()
            }
        }
    }

    func loadPeripheralServicesFromConfig() {
        if let peripheral = self.peripheral {
            let peripheralManager = PeripheralManager.sharedInstance()
            let profileManager = ProfileManager.sharedInstance()
            let serviceUUIDs = PeripheralStore.getPeripheralServices(peripheral)
            let services = serviceUUIDs.reduce([MutableService]()){(servs, uuidString) in
                if let uuid = CBUUID.UUIDWithString(uuidString) {
                    if let serviceProfile = profileManager.service(uuid) {
                        let service = MutableService(profile:serviceProfile)
                        service.characteristicsFromProfiles(serviceProfile.characteristics)
                        return servs + [service]
                    } else {
                        return servs
                    }
                } else {
                    return servs
                }
            }
            peripheralManager.addServices(services, afterServiceAddSuccess:{
                self.setUIState()
                },  afterServiceAddFailed:{(error) in
                    self.setUIState()
                    self.presentViewController(UIAlertController.alertOnError(error), animated:true, completion:nil)
            })
        }
    }

    func setUIState() {
        if self.peripheral != nil {
            self.advertiseButton.enabled = true
            let peripheralManager = PeripheralManager.sharedInstance()
            if peripheralManager.isAdvertising {
                self.advertiseButton.setTitle("Stop Advertising", forState:.Normal)
                self.servicesLable.textColor = UIColor.lightGrayColor()
                self.advertiseButton.setTitleColor(UIColor(red:0.7, green:0.1, blue:0.1, alpha:1.0), forState:.Normal)
                self.navigationItem.setHidesBackButton(true, animated:true)
                self.nameTextField.enabled = false
            } else {
                self.servicesLable.textColor = UIColor.blackColor()
                self.advertiseButton.setTitle("Start Advertising", forState:.Normal)
                self.advertiseButton.setTitleColor(UIColor(red:0.1, green:0.7, blue:0.1, alpha:1.0), forState:.Normal)
                self.navigationItem.setHidesBackButton(false, animated:true)
                self.nameTextField.enabled = true
            }
        } else {
            self.servicesLable.textColor = UIColor.grayColor()
            self.advertiseButton.setTitleColor(UIColor(red:0.7, green:0.7, blue:0.7, alpha:1.0), forState:.Normal)
            self.advertiseButton.enabled = false
        }
    }
    
    // UITextFieldDelegate
    func textFieldShouldReturn(textField: UITextField!) -> Bool {
        self.nameTextField.resignFirstResponder()
        if let enteredName = self.nameTextField.text {
            if enteredName != "" {
                if let oldname = self.peripheral {
                    let services = PeripheralStore.getPeripheralServices(oldname)
                    PeripheralStore.removePeripheral(oldname)
                    PeripheralStore.addPeripheral(enteredName)
                    PeripheralStore.addPeripheralServices(enteredName, services:services)
                    self.peripheral = enteredName
                } else {
                    self.peripheral = enteredName
                    PeripheralStore.addPeripheral(enteredName)
                }
            }
            self.setUIState()
        }
        return true
    }

}