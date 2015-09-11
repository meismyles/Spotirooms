//
//  RoomListVC.swift
//  Spotirooms
//
//  Created by Myles Ringle on 10/08/2015.
//  Copyright (c) 2015 Myles Ringle. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import DTIActivityIndicator
import CryptoSwift

class RoomListVC: UIViewController, UITableViewDataSource, UITableViewDelegate {

    let userDefaults = NSUserDefaults.standardUserDefaults()
    var tabBarC: TabBarC!
    
    @IBOutlet weak var newRoom_button: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loadingCoverView: UIView!
    var myActivityIndicatorView: DTIActivityIndicatorView!
    var refreshControl:UIRefreshControl!
    
    var popover: UIPopoverController? = nil
    
    var rooms: Array<JSON>! = []
    var selectedRoom_info: JSON?
    var noRoomsToShow: Bool = true
    var newRoomID: Int?
    var selectedIndexPath: NSIndexPath?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.tableView.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
        self.tableView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.4)
        
        // Do any additional setup after loading the view, typically from a nib.
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refreshControl)
        
        // Remove back button title in future pushed views
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title:"", style:.Done, target:nil, action:nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0).colorWithAlphaComponent(0.95)
        
        // Show activity indicator
        self.myActivityIndicatorView = DTIActivityIndicatorView(frame: CGRect(x:self.view.center.x-40, y:self.view.center.y-80, width:80.0, height:80.0))
        self.loadingCoverView.addSubview(self.myActivityIndicatorView)
        self.myActivityIndicatorView.indicatorColor = UIColor.whiteColor()
        self.myActivityIndicatorView.indicatorStyle = "spotify"
        self.myActivityIndicatorView.startActivity()
        
        self.loadRoomList()
    }
    
    func showLoadingCell() {
        if let selectedIndexPath: NSIndexPath = self.tableView.indexPathForSelectedRow() {
            var cell = tableView.cellForRowAtIndexPath(selectedIndexPath)
            self.tableView.userInteractionEnabled = false
            self.navigationItem.rightBarButtonItem?.enabled = false
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
        if self.tableView.indexPathForSelectedRow() != nil {
            self.selectedIndexPath = self.tableView.indexPathForSelectedRow()
        }
        if let selectedIndexPath: NSIndexPath = self.selectedIndexPath {
            var cell = tableView.cellForRowAtIndexPath(selectedIndexPath)
            //cell!.contentView.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
            cell!.contentView.backgroundColor = UIColor.clearColor()
            if let coverView = cell!.viewWithTag(1) {
                coverView.removeFromSuperview()
            }
            if let activityIndicator = cell!.viewWithTag(2) {
                activityIndicator.removeFromSuperview()
            }
            self.selectedIndexPath = nil
        }
    }
    
    func hideLoadingView() {
        self.myActivityIndicatorView.stopActivity(true)
        UIView.animateWithDuration(0.5, animations: {
            self.loadingCoverView.alpha = 0
            }, completion: { _ in
                self.loadingCoverView.hidden = true
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func refresh(sender:AnyObject) {
        self.loadRoomList()
    }
    
    func loadRoomList() {
        Alamofire.request(.POST, "\(Constants.serverURL)/api/get_rooms", encoding: .JSON)
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
                    self.hideLoadingView()
                    var json = JSON(json!)
                    // Server Error
                    if let error = json["error"].string {
                        self.noRoomsToShow = true
                    }
                    else {
                        self.noRoomsToShow = false
                        self.rooms = json["results"].arrayValue
                    }
                    self.refreshControl.endRefreshing()
                    self.tableView.reloadData()
                    
                    if let room_id = self.newRoomID {
                        for var i = 0; i < self.rooms.count; i++ {
                            let room = self.rooms[i]
                            if room_id == room["room_id"].intValue {
                                let indexPath = NSIndexPath(forRow: i, inSection: 0)
                                self.selectedIndexPath = indexPath
                                self.tableView(self.tableView, didSelectRowAtIndexPath: indexPath)
                            }
                        }
                        self.newRoomID = nil
                    }
                }
        }
    }
    
    @IBAction func newRoom() {
        self.performSegueWithIdentifier("newRoom", sender: nil)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "roomSegue" {
            weak var roomVC = segue.destinationViewController as? RoomVC
            roomVC!.room_info = self.selectedRoom_info
        }
    }
    
    @IBAction func endNewRoom(segue: UIStoryboardSegue) {
        if segue.identifier == "finishNewRoom" {
            weak var newRoomVC = segue.sourceViewController as? NewRoomVC
            if let room_id = newRoomVC?.room_id {
                self.newRoomID = room_id
            }
            self.loadRoomList()
        }
    }
    
    func checkPass(room_info: JSON, pass: String!, cell: UITableViewCell, indexPath: NSIndexPath) {
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
                            cell.contentView.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05)
                            self.selectedRoom_info = self.rooms[indexPath.row]
                            self.tabBarC.addRoomView(self.selectedRoom_info!, fromView: 0)
                        }
                    }
                }
        }

    }
    
    // UITableViewDataSource methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = self.noRoomsToShow ? 1 : self.rooms.count
        return count
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if self.noRoomsToShow == false {
            return 64
        }
        else {
            return 50
        }
    }
    
    /*func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = UIColor(red: 0.8405, green: 0.8405, blue: 0.8405, alpha: 1.0)
        
        var headerIndexText: UITableViewHeaderFooterView = view as! UITableViewHeaderFooterView
        headerIndexText.textLabel.font = UIFont(name: "Menlo-Regular", size: 13)
        headerIndexText.textLabel.textColor = UIColor.blackColor()
    }*/
    
    /*func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Header \(section+1)"
    }*/
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if self.noRoomsToShow == false {
            var cell = tableView.dequeueReusableCellWithIdentifier("RoomListCell") as? RoomListCell
            
            if cell == nil {
                cell = RoomListCell()
            }
            
            let room_info = self.rooms[indexPath.row]
            cell!.titleField.text = room_info["name"].string
            cell!.descriptionField.text = room_info["description"].string!
            cell!.usersField.text = String(room_info["active_users"].intValue) + " Users"
            
            //cell!.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
            cell!.backgroundColor = UIColor.clearColor()
            cell!.selectionStyle = UITableViewCellSelectionStyle.None
            
            return cell!
        }
        else {
            var cell = tableView.dequeueReusableCellWithIdentifier("cell") as? UITableViewCell
            
            if cell == nil {
                cell = UITableViewCell(style: UITableViewCellStyle.Value1, reuseIdentifier: "cell")
            }
            
            cell!.textLabel?.text = "Oh noes! There's no rooms!"
            cell!.detailTextLabel?.text = "Why not create one?"
            
            //cell!.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
            cell!.backgroundColor = UIColor.clearColor()
            cell!.textLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 16)
            cell!.textLabel?.textColor = UIColor.whiteColor()
            cell!.detailTextLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 13)
            cell!.detailTextLabel?.textColor = UIColor.lightGrayColor()
            cell!.selectionStyle = UITableViewCellSelectionStyle.None
            
            return cell!
        }
    }
    
    // UITableViewDelegate methods
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var cell = tableView.cellForRowAtIndexPath(indexPath)
        
        if self.noRoomsToShow == false {
            let room_info = self.rooms[indexPath.row]
            if self.selectedRoom_info == nil || self.selectedRoom_info!["room_id"].intValue != room_info["room_id"].intValue {
                if room_info["private"].intValue == 0 {
                    cell!.contentView.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05)
                    self.selectedRoom_info = self.rooms[indexPath.row]
                    self.tabBarC.addRoomView(self.selectedRoom_info!, fromView: 0)
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
                        self.checkPass(room_info, pass: textField.text, cell: cell!, indexPath: indexPath)
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

