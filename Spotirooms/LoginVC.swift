//
//  LoginVC.swift
//  Spotirooms
//
//  Created by Myles Ringle on 10/08/2015.
//  Copyright (c) 2015 Myles Ringle. All rights reserved.
//

import UIKit

class LoginVC: UIViewController, SPTAuthViewDelegate {
    
    var authViewController: SPTAuthViewController!
    var firstLoad: Bool!
    
    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "sessionUpdatedNotification", name: "sessionUpdated", object: nil)
        self.firstLoad = true
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
        self.firstLoad = false
        self.performSegueWithIdentifier("loginSegue", sender: nil)
    }
    
    
    ////////////////////////////////////////////////////////////
    // IBAction Methods
    
    @IBAction func loginClicked(sender: AnyObject) {
        self.openLoginPage()
    }
    
    
    ////////////////////////////////////////////////////////////
    // SPTAuthView Delegate Methods
    
    func authenticationViewController(authenticationViewController: SPTAuthViewController!, didFailToLogin error: NSError!) {
        println("*** Failed to log in: \(error)")
    }
    
    func authenticationViewController(authenticationViewController: SPTAuthViewController!, didLoginWithSession session: SPTSession!) {
        self.showHome()
    }
    
    func authenticationViewControllerDidCancelLogin(authenticationViewController: SPTAuthViewController!) {
        println("*** Login cancelled.")
    }
    
}
