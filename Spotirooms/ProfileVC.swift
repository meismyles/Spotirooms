//
//  ProfileVC.swift
//  Spotirooms
//
//  Created by Myles Ringle on 10/08/2015.
//  Copyright (c) 2015 Myles Ringle. All rights reserved.
//

import UIKit
import WebImage
import Alamofire
import SwiftyJSON
import DTIActivityIndicator
import CryptoSwift

class ProfileVC: UIViewController, UITableViewDataSource, UITableViewDelegate {

    let userDefaults = NSUserDefaults.standardUserDefaults()
    var tabBarC: TabBarC!
    
    @IBOutlet weak var userImageView: UIImageView!
    @IBOutlet weak var userFullNameField: UILabel!
    @IBOutlet weak var curatedTableView: UITableView!
    @IBOutlet weak var recentTableView: UITableView!
    
    var curatedRefreshControl:UIRefreshControl!
    var curatedRooms: Array<JSON>! = []
    var noCuratedRoomsToShow: Bool = true
    var curatedSelectedIndexPath: NSIndexPath?
    
    var recentRefreshControl:UIRefreshControl!
    var recentRooms: Array<JSON>! = []
    var noRecentRoomsToShow: Bool = true
    var recentSelectedIndexPath: NSIndexPath?
    
    var selectedRoom_info: JSON?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.view.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
        self.curatedTableView.backgroundColor = UIColor(red: 0.1161, green: 0.1256, blue: 0.1368, alpha: 1.0)
        self.recentTableView.backgroundColor = UIColor(red: 0.1161, green: 0.1256, blue: 0.1368, alpha: 1.0)
        self.userImageView.layer.shadowColor = UIColor.blackColor().CGColor
        self.userImageView.layer.shadowOffset = CGSizeMake(0, 0)
        self.userImageView.layer.shadowOpacity = 0.4
        self.userImageView.layer.shadowRadius = 2.0
        
        self.curatedRefreshControl = UIRefreshControl()
        self.curatedRefreshControl.addTarget(self, action: "refreshCurated:", forControlEvents: UIControlEvents.ValueChanged)
        self.curatedTableView.addSubview(curatedRefreshControl)
        self.recentRefreshControl = UIRefreshControl()
        self.recentRefreshControl.addTarget(self, action: "refreshRecent:", forControlEvents: UIControlEvents.ValueChanged)
        self.recentTableView.addSubview(recentRefreshControl)
        
        var auth = SPTAuth.defaultInstance()
        
        SPTUser.requestCurrentUserWithAccessToken(auth.session.accessToken, callback: { (error: NSError!, results: AnyObject!) -> Void in
            let user = results as! SPTUser
            self.userFullNameField.text = user.displayName
            if let imageURL = user.largestImage?.imageURL {
                self.userImageView.sd_setImageWithURL(imageURL,
                    placeholderImage: UIImage(named: "Artwork-Placeholder"),
                    completed: { (image: UIImage!, error: NSError!, cacheType: SDImageCacheType, imageURL: NSURL!) in
                        
                        if error != nil {
                            println("*** Error downloading image: \(error)")
                            return
                        }
                        
                        if image != nil && cacheType == SDImageCacheType.None {
                            self.userImageView.alpha = 0.0;
                            UIView.animateWithDuration(0.3, animations: {
                                self.userImageView.alpha = 1.0
                            })
                        }
                })
            }

        })
    }
    
    override func viewWillAppear(animated: Bool) {        
        self.loadCuratedRoomList()
        self.loadRecentRoomList()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func refreshCurated(sender:AnyObject) {
        self.loadCuratedRoomList()
    }
    
    func refreshRecent(sender:AnyObject) {
        self.loadRecentRoomList()
    }
    
    func loadCuratedRoomList() {
        Alamofire.request(.POST, "\(Constants.serverURL)/api/get_curated_rooms", encoding: .JSON)
            .authenticate(user: self.userDefaults.stringForKey("session_token")!, password: "")
            .responseJSON {(request, response, json, error) in
                // Network Error
                if(error != nil) {
                    NSLog("Error: \(error)")
                    println(request)
                    println()
                    println(response)
                }
                else {
                    var json = JSON(json!)
                    // Server Error
                    if let error = json["error"].string {
                        self.noCuratedRoomsToShow = true
                    }
                    else {
                        self.noCuratedRoomsToShow = false
                        self.curatedRooms = json["results"].arrayValue
                    }
                    self.curatedRefreshControl.endRefreshing()
                    self.curatedTableView.reloadData()
                }
        }
    }

    
    func loadRecentRoomList() {
        Alamofire.request(.POST, "\(Constants.serverURL)/api/get_recent_rooms", encoding: .JSON)
            .authenticate(user: self.userDefaults.stringForKey("session_token")!, password: "")
            .responseJSON {(request, response, json, error) in
                // Network Error
                if(error != nil) {
                    NSLog("Error: \(error)")
                    println(request)
                    println()
                    println(response)
                }
                else {
                    var json = JSON(json!)
                    // Server Error
                    if let error = json["error"].string {
                        self.noRecentRoomsToShow = true
                    }
                    else {
                        self.noRecentRoomsToShow = false
                        self.recentRooms = json["results"].arrayValue
                    }
                    self.recentRefreshControl.endRefreshing()
                    self.recentTableView.reloadData()
                }
        }
    }
    
    func showLoadingCell() {
        if let selectedIndexPath: NSIndexPath = self.curatedTableView.indexPathForSelectedRow() {
            var cell = curatedTableView.cellForRowAtIndexPath(selectedIndexPath)
            self.curatedTableView.userInteractionEnabled = false
            var coverView = UIView(frame: CGRectMake(0, 0, cell!.bounds.width, cell!.bounds.height))
            coverView.tag = 1
            coverView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.4)
            cell!.contentView.addSubview(coverView)
            var cellActivityIndicator = DTIActivityIndicatorView(frame: CGRectMake(cell!.bounds.width-(cell!.bounds.width/2)-(cell!.bounds.height/2), 0, cell!.bounds.height, cell!.bounds.height))
            cell!.contentView.addSubview(cellActivityIndicator)
            cellActivityIndicator.tag = 2
            cellActivityIndicator.indicatorColor = UIColor.whiteColor()
            cellActivityIndicator.indicatorStyle = "spotify"
            cellActivityIndicator.userInteractionEnabled = false
            cellActivityIndicator.startActivity()
        }
        else if let selectedIndexPath: NSIndexPath = self.recentTableView.indexPathForSelectedRow() {
            var cell = recentTableView.cellForRowAtIndexPath(selectedIndexPath)
            self.recentTableView.userInteractionEnabled = false
            var coverView = UIView(frame: CGRectMake(0, 0, cell!.bounds.width, cell!.bounds.height))
            coverView.tag = 1
            coverView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.4)
            cell!.contentView.addSubview(coverView)
            var cellActivityIndicator = DTIActivityIndicatorView(frame: CGRectMake(cell!.bounds.width-(cell!.bounds.width/2)-(cell!.bounds.height/2), 0, cell!.bounds.height, cell!.bounds.height))
            cell!.contentView.addSubview(cellActivityIndicator)
            cellActivityIndicator.tag = 2
            cellActivityIndicator.indicatorColor = UIColor.whiteColor()
            cellActivityIndicator.indicatorStyle = "spotify"
            cellActivityIndicator.userInteractionEnabled = false
            cellActivityIndicator.startActivity()
        }
    }
    
    func deselectCells() {
        if self.curatedTableView.indexPathForSelectedRow() != nil {
            self.curatedSelectedIndexPath = self.curatedTableView.indexPathForSelectedRow()
        }
        if let selectedIndexPath: NSIndexPath = self.curatedSelectedIndexPath {
            var cell = curatedTableView.cellForRowAtIndexPath(selectedIndexPath)
            cell!.contentView.backgroundColor = UIColor(red: 0.1161, green: 0.1256, blue: 0.1368, alpha: 1.0)
            if let coverView = cell!.viewWithTag(1) {
                coverView.removeFromSuperview()
            }
            if let activityIndicator = cell!.viewWithTag(2) {
                activityIndicator.removeFromSuperview()
            }
            self.curatedSelectedIndexPath = nil
        }
        
        if self.recentTableView.indexPathForSelectedRow() != nil {
            self.recentSelectedIndexPath = self.recentTableView.indexPathForSelectedRow()
        }
        if let selectedIndexPath: NSIndexPath = self.recentSelectedIndexPath {
            var cell = recentTableView.cellForRowAtIndexPath(selectedIndexPath)
            cell!.contentView.backgroundColor = UIColor(red: 0.1161, green: 0.1256, blue: 0.1368, alpha: 1.0)
            if let coverView = cell!.viewWithTag(1) {
                coverView.removeFromSuperview()
            }
            if let activityIndicator = cell!.viewWithTag(2) {
                activityIndicator.removeFromSuperview()
            }
            self.recentSelectedIndexPath = nil
        }
    }

    func checkPass(room_info: JSON, pass: String!, cell: UITableViewCell, indexPath: NSIndexPath, roomType: Int) {
        let hashedPass = pass.sha256()!
        
        let parameters = [
            "room_id": room_info["room_id"].stringValue,
            "pass": hashedPass
        ]
        Alamofire.request(.POST, "\(Constants.serverURL)/api/check_pass", parameters: parameters, encoding: .JSON)
            .authenticate(user: self.userDefaults.stringForKey("session_token")!, password: "")
            .responseJSON {(request, response, json, error) in
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
                        let success = json["data"].intValue
                        if success == 1 {
                            if roomType == 0 {
                                cell.contentView.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05)
                                self.selectedRoom_info = self.curatedRooms[indexPath.row]
                                self.tabBarC.addRoomView(self.selectedRoom_info!, fromView: 1)
                            }
                            else if roomType == 1 {
                                cell.contentView.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05)
                                self.selectedRoom_info = self.recentRooms[indexPath.row]
                                self.tabBarC.addRoomView(self.selectedRoom_info!, fromView: 1)
                            }
                        }
                    }
                }
        }
        
    }

    
    ///////////////////////////////////////////////////
    // UITableViewDataSource methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count = 0
        if tableView == self.curatedTableView {
            count = self.noCuratedRoomsToShow ? 1 : self.curatedRooms.count
        }
        else {
            count = self.noRecentRoomsToShow ? 1 : self.recentRooms.count
        }
        return count
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("cell") as? UITableViewCell
        
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCellStyle.Value1, reuseIdentifier: "cell")
        }
        
        if tableView == self.curatedTableView {
            if self.noCuratedRoomsToShow == false {
                let room_info = self.curatedRooms[indexPath.row]
                cell!.textLabel?.text = room_info["name"].string
                cell!.detailTextLabel?.text = String(room_info["active_users"].intValue) + " Users"
            }
            else {
                cell!.textLabel?.text = "You don't curate any rooms!"
                cell!.detailTextLabel?.text = ""
            }
        }
        else {
            if self.noRecentRoomsToShow == false {
                let room_info = self.recentRooms[indexPath.row]
                cell!.textLabel?.text = room_info["name"].string
                cell!.detailTextLabel?.text = String(room_info["active_users"].intValue) + " Users"
            }
            else {
                cell!.textLabel?.text = "You have no recent rooms!"
                cell!.detailTextLabel?.text = ""
            }
        }
        
        
        cell!.backgroundColor = UIColor(red: 0.1161, green: 0.1256, blue: 0.1368, alpha: 1.0)
        cell!.textLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 16)
        cell!.textLabel?.textColor = UIColor.whiteColor()
        cell!.detailTextLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 13)
        cell!.detailTextLabel?.textColor = UIColor.lightGrayColor()
        cell!.selectionStyle = UITableViewCellSelectionStyle.None
        
        return cell!
    }
    
    // UITableViewDelegate methods
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var cell = tableView.cellForRowAtIndexPath(indexPath)
        
        if tableView == self.curatedTableView {
            if self.noCuratedRoomsToShow == false {
                let room_info = self.curatedRooms[indexPath.row]
                if self.selectedRoom_info == nil || self.selectedRoom_info!["room_id"].intValue != room_info["room_id"].intValue {
                    if room_info["private"].intValue == 0 {
                        cell!.contentView.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05)
                        self.selectedRoom_info = self.curatedRooms[indexPath.row]
                        self.tabBarC.addRoomView(self.selectedRoom_info!, fromView: 1)
                    }
                    else {
                        //1. Create the alert controller.
                        var alert = UIAlertController(title: "Private Room", message: "Please enter the room password.", preferredStyle: .Alert)
                        
                        //2. Add the text field. You can configure it however you need.
                        alert.addTextFieldWithConfigurationHandler({ (textField) -> Void in
                            textField.placeholder = "Password"
                            textField.secureTextEntry = true
                        })
                        
                        //3. Grab the value from the text field, and print it when the user clicks OK.
                        alert.addAction(UIAlertAction(title: "Cancel", style: .Default, handler: nil))
                        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
                            let textField = alert.textFields![0] as! UITextField
                            self.checkPass(room_info, pass: textField.text, cell: cell!, indexPath: indexPath, roomType: 0)
                        }))
                        
                        // 4. Present the alert.
                        self.presentViewController(alert, animated: true, completion: nil)
                    }

                }
                else {
                    var alert = UIAlertController(title: "Sorry", message: "You are already a member of this room.", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                }
            }
        }
        else {
            if self.noRecentRoomsToShow == false {
                let room_info = self.recentRooms[indexPath.row]
                if self.selectedRoom_info == nil || self.selectedRoom_info!["room_id"].intValue != room_info["room_id"].intValue {
                    if room_info["private"].intValue == 0 {
                        cell!.contentView.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05)
                        self.selectedRoom_info = self.recentRooms[indexPath.row]
                        self.tabBarC.addRoomView(self.selectedRoom_info!, fromView: 1)
                    }
                    else {
                        //1. Create the alert controller.
                        var alert = UIAlertController(title: "Private Room", message: "Please enter the room password.", preferredStyle: .Alert)
                        
                        //2. Add the text field. You can configure it however you need.
                        alert.addTextFieldWithConfigurationHandler({ (textField) -> Void in
                            textField.placeholder = "Password"
                            textField.secureTextEntry = true
                        })
                        
                        //3. Grab the value from the text field, and print it when the user clicks OK.
                        alert.addAction(UIAlertAction(title: "Cancel", style: .Default, handler: nil))
                        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
                            let textField = alert.textFields![0] as! UITextField
                            self.checkPass(room_info, pass: textField.text, cell: cell!, indexPath: indexPath, roomType: 1)
                        }))
                        
                        // 4. Present the alert.
                        self.presentViewController(alert, animated: true, completion: nil)
                    }
                }
                else {
                    var alert = UIAlertController(title: "Sorry", message: "You are already a member of this room.", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                }
            }
        }
        
    }


}

