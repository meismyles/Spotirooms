//
//  AppDelegate.swift
//  Spotirooms
//
//  Created by Myles Ringle on 10/08/2015.
//  Copyright (c) 2015 Myles Ringle. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var nc: NetworkClock!

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        
        self.nc = NetworkClock.sharedNetworkClock()
        
        UINavigationBar.appearance().barStyle = UIBarStyle.Black
        UITabBar.appearance().tintColor = UIColor.whiteColor()
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        var auth: SPTAuth = SPTAuth.defaultInstance()
        auth.clientID = Constants.clientID
        auth.requestedScopes = [SPTAuthStreamingScope, SPTAuthUserReadPrivateScope]
        auth.redirectURL = NSURL(string: Constants.callbackURL)

        // Check for valid session token
        // ************** NEED TO CHECK SPOTIFY SESSION HERE AS WELL
        /*if (NSUserDefaults.standardUserDefaults().stringForKey("session_token") != nil) && (auth.session != nil) {
            if auth.session.isValid() {
                Alamofire.request(.POST, "\(Constants.serverURL)/api/session_check", encoding: .JSON)
                    .authenticate(user: NSUserDefaults.standardUserDefaults().stringForKey("session_token")!, password: "")
                    .responseJSON {(request, response, json, error) in
                        if(error == nil) {
                            var json = JSON(json!)
                            // Server Error
                            if json["success"].string != nil {
                                let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                                var homeViewController = mainStoryboard.instantiateViewControllerWithIdentifier("RoomListVC") as!
                                RoomListVC
                                self.window!.rootViewController = homeViewController
                            }
                        }
                }
            }
        }*/
        
        return true
    }

    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {
        
        var auth: SPTAuth = SPTAuth.defaultInstance()
    
        let authCallback = { (error: NSError!, session: SPTSession!) -> Void in
            // Callback will be triggered when auth completes
            if error != nil {
                println("*** Auth Error: \(error)")
                return
            }
            
            auth.session = session
            NSNotificationCenter.defaultCenter().postNotificationName("loginSuccessful", object: nil)
            
        }
        
        if auth.canHandleURL(url) {
            auth.handleAuthCallbackWithTriggeredAuthURL(url, callback: authCallback)
            return true
        }
        
        return false
        
    }

    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        UIApplication.sharedApplication().endReceivingRemoteControlEvents()
    }


}

