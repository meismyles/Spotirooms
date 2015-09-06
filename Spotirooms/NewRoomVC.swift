//
//  NewRoomVC.swift
//  Spotirooms
//
//  Created by Myles Ringle on 25/08/2015.
//  Copyright (c) 2015 Myles Ringle. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

class NewRoomVC: UIViewController {
    
    let userDefaults = NSUserDefaults.standardUserDefaults()
    
    @IBOutlet weak var done_button: UIBarButtonItem!
    var done_button_store: UIBarButtonItem!
    @IBOutlet weak var cancel_button: UIBarButtonItem!
    @IBOutlet weak var name_field: UITextField!
    var public_or_private: Int! = 0
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    var room_id: Int?
    
    override func viewDidAppear(animated: Bool) {
        self.name_field.becomeFirstResponder()
    }
    
    @IBAction func indexChanged(sender: UISegmentedControl) {
        switch self.segmentedControl.selectedSegmentIndex {
        case 0:
            self.public_or_private = 0
        case 1:
            self.public_or_private = 1
        default:
            break
        }
    }
    
    @IBAction func createRoom() {
        if count(self.name_field.text) < 3 {
            var alert = UIAlertController(title: "Error", message: "Name must be at least 3 characters.", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }
        else {
            self.startActivityIndicator()
            
            let parameters = [
                "name": self.name_field.text,
                "private": String(self.public_or_private)
            ]
            Alamofire.request(.POST, "\(Constants.serverURL)/api/create_room", parameters: parameters, encoding: .JSON)
                .authenticate(user: self.userDefaults.stringForKey("session_token")!, password: "")
                .responseJSON {(request, response, json, error) in
                    self.endActivityIndicator()
                    // Network Error
                    if(error != nil) {
                        NSLog("***** ERROR: \(error)")
                        println("***** REQUEST: \(request)")
                        println("***** RESPONSE: \(response)")
                        var alert = UIAlertController(title: "Error", message: "Could not connect to server.", preferredStyle: UIAlertControllerStyle.Alert)
                        alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                        self.presentViewController(alert, animated: true, completion: nil)
                    }
                    else {
                        var json = JSON(json!)
                        // Server Error
                        if let error = json["error"].string {
                            var alert = UIAlertController(title: "Error", message: error, preferredStyle: UIAlertControllerStyle.Alert)
                            alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                            self.presentViewController(alert, animated: true, completion: nil)
                        }
                        else {
                            self.room_id = json["room_id"].intValue
                            self.performSegueWithIdentifier("finishNewRoom", sender: nil)
                        }
                    }
            }
        }
    }
    
    func startActivityIndicator() {
        var activityIndicator = UIActivityIndicatorView(frame: CGRectMake(0,0, 20, 20)) as UIActivityIndicatorView
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.Gray
        var barButton = UIBarButtonItem(customView: activityIndicator)
        done_button_store = self.navigationItem.rightBarButtonItem
        self.navigationItem.rightBarButtonItem = barButton
        activityIndicator.startAnimating()
    }
    
    func endActivityIndicator() {
        self.navigationItem.rightBarButtonItem = done_button_store
    }
    
}
