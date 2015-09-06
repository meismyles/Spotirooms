//
//  LoginVC.swift
//  Spotirooms
//
//  Created by Myles Ringle on 10/08/2015.
//  Copyright (c) 2015 Myles Ringle. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import DTIActivityIndicator

class LoginVC: UIViewController, SPTAuthViewDelegate {
    
    let userDefaults = NSUserDefaults.standardUserDefaults()
    var authViewController: SPTAuthViewController!
    @IBOutlet weak var loginButton: UIButton!
    var activityIndicator: DTIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "sessionUpdatedNotification", name: "sessionUpdated", object: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.loginButton.enabled = true
    }
    
    func sessionUpdatedNotification(notification: NSNotification) {
        if self.navigationController?.topViewController == self {
            var auth: SPTAuth = SPTAuth.defaultInstance()
            if auth.session != nil && auth.session.isValid() == true {
                self.performSegueWithIdentifier("loginSegue", sender: nil)
            }
        }
    }
    
    func openLoginPage() {
        self.authViewController = SPTAuthViewController.authenticationViewController()
        self.authViewController.delegate = self
        self.authViewController.modalPresentationStyle = UIModalPresentationStyle.OverCurrentContext
        self.authViewController.modalTransitionStyle = UIModalTransitionStyle.CrossDissolve
        
        self.modalPresentationStyle = UIModalPresentationStyle.CurrentContext
        self.definesPresentationContext = true
        
        self.presentViewController(self.authViewController, animated: false, completion: nil)
    }
    
    func showHome() {
        self.performSegueWithIdentifier("loginSegue", sender: nil)
    }
    
    /*override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "loginSegue" {
            var tabBarController = segue.destinationViewController as! UITabBarController
            var navController = tabBarController.viewControllers![0] as! UINavigationController
            var firstVC = navController.topViewController as! FirstViewController
            firstVC.auth = self.auth
        }
    }*/
    
    ////////////////////////////////////////////////////////////
    // IBAction Methods
    
    @IBAction func loginClicked(sender: AnyObject) {
        self.loginButton.enabled = false
        self.activityIndicator = DTIActivityIndicatorView(frame: CGRectMake(self.loginButton.bounds.width-(self.loginButton.bounds.width/2)-(self.loginButton.bounds.height/2), 0, self.loginButton.bounds.height, self.loginButton.bounds.height))
        self.loginButton.addSubview(self.activityIndicator)
        self.activityIndicator.indicatorColor = UIColor.whiteColor()
        self.activityIndicator.indicatorStyle = "spotify"
        self.activityIndicator.userInteractionEnabled = false
        self.activityIndicator.startActivity()
        self.openLoginPage()
    }
    
    
    ////////////////////////////////////////////////////////////
    // SPTAuthView Delegate Methods
    
    func authenticationViewController(authenticationViewController: SPTAuthViewController!, didFailToLogin error: NSError!) {
        println("*** Failed to log in: \(error)")
        self.activityIndicator.stopActivity()
        self.loginButton.enabled = true
        var alert = UIAlertController(title: "Error", message: "Failed to log in to Spotify.", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func authenticationViewController(authenticationViewController: SPTAuthViewController!, didLoginWithSession session: SPTSession!) {
        var auth = SPTAuth.defaultInstance()
        
        SPTUser.requestCurrentUserWithAccessToken(auth.session.accessToken, callback: { (error: NSError!, results: AnyObject!) -> Void in
            let user = results as! SPTUser
            let parameters = [
                "username": user.canonicalUserName,
                "fullname": user.displayName,
                "client_id": Constants.clientID
            ]
            Alamofire.request(.POST, "\(Constants.serverURL)/api/login", parameters: parameters, encoding: .JSON)
                .responseJSON {(request, response, json, error) in
                    // Network Error
                    if(error != nil) {
                        NSLog("***** ERROR: \(error)")
                        println("***** REQUEST: \(request)")
                        println("***** RESPONSE: \(response)")
                        self.activityIndicator.stopActivity()
                        self.loginButton.enabled = true
                        var alert = UIAlertController(title: "Error", message: "Could not connect to server.", preferredStyle: UIAlertControllerStyle.Alert)
                        alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                        self.presentViewController(alert, animated: true, completion: nil)
                    }
                    else {
                        var json = JSON(json!)
                        // Server Error
                        if let error = json["error"].string {
                            self.activityIndicator.stopActivity()
                            self.loginButton.enabled = true
                            var alert = UIAlertController(title: "Error", message: error, preferredStyle: UIAlertControllerStyle.Alert)
                            alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                            self.presentViewController(alert, animated: true, completion: nil)
                        }
                        else {
                            self.userDefaults.setValue(json["token"].string, forKey: "session_token")
                            self.activityIndicator.stopActivity()
                            self.showHome()
                        }
                    }
            }
        })
    }
    
    func authenticationViewControllerDidCancelLogin(authenticationViewController: SPTAuthViewController!) {
        println("*** Login cancelled.")
        self.activityIndicator.stopActivity()
        self.loginButton.enabled = true
    }
    
}
