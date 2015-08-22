//
//  FirstViewController.swift
//  Spotirooms
//
//  Created by Myles Ringle on 10/08/2015.
//  Copyright (c) 2015 Myles Ringle. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController {

    let clientID = "704562d42a754b50a52a77c754d13ad6"
    let callbackURL = "spotirooms://callback"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        var auth: SPTAuth = SPTAuth.defaultInstance()
        
        SPTUser.requestCurrentUserWithAccessToken(auth.session.accessToken, callback: { (error: NSError!, results: AnyObject!) -> Void in
            let user = results as! SPTUser
            println("Display Name: \(user.displayName)")
            println("Canonical Name: \(user.canonicalUserName)")
            println("Email: \(user.emailAddress)")
        })
    }
    
    override func viewDidAppear(animated: Bool) {
        var URL: NSURL = NSURL(string: "http://127.0.0.1:5000/login")!
        var request:NSMutableURLRequest = NSMutableURLRequest(URL:URL)
        request.HTTPMethod = "POST"
        var bodyData = "username=john&testing=iOSwinner"
        request.HTTPBody = bodyData.dataUsingEncoding(NSUTF8StringEncoding)
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {
            (response, data, error) in
            println(NSString(data: data, encoding: NSUTF8StringEncoding))
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

