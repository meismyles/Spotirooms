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

class RoomListVC: UIViewController, UITableViewDataSource, UITableViewDelegate {

    let userDefaults = NSUserDefaults.standardUserDefaults()
    
    @IBOutlet weak var newRoom_button: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loadingCoverView: UIView!
    var myActivityIndicatorView: DTIActivityIndicatorView!
    var refreshControl:UIRefreshControl!
    
    var popover: UIPopoverController? = nil
    
    var rooms: Array<JSON>! = []
    var selectedRoom_info: JSON!
    var noRoomsToShow: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refreshControl)
        
        // Remove back button title in future pushed views
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title:"", style:.Done, target:nil, action:nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let selectedIndexPath: NSIndexPath = self.tableView.indexPathForSelectedRow() {
            var cell = tableView.cellForRowAtIndexPath(selectedIndexPath)
            cell!.contentView.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
        }
        
        // Show activity indicator
        self.myActivityIndicatorView = DTIActivityIndicatorView(frame: CGRect(x:self.view.center.x-40, y:self.view.center.y-80, width:80.0, height:80.0))
        self.loadingCoverView.addSubview(self.myActivityIndicatorView)
        self.myActivityIndicatorView.indicatorColor = UIColor.whiteColor()
        self.myActivityIndicatorView.indicatorStyle = "spotify"
        self.myActivityIndicatorView.startActivity()
        
        self.loadRoomList()
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
                }
        }
    }
    
    @IBAction func newRoom() {
        self.performSegueWithIdentifier("newRoom", sender: nil)
    }
    
    @IBAction func endNewRoom(segue: UIStoryboardSegue) {
        if segue.identifier == "finishNewRoom" {
            self.loadRoomList()
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "roomSegue" {
            var roomVC = segue.destinationViewController as! RoomVC
            roomVC.room_info = self.selectedRoom_info
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
        return 50
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
        var cell = tableView.dequeueReusableCellWithIdentifier("cell") as? UITableViewCell
        
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCellStyle.Value1, reuseIdentifier: "cell")
        }
        
        if self.noRoomsToShow == false {
            let room_info = self.rooms[indexPath.row]
            cell!.textLabel?.text = room_info["name"].string
            cell!.detailTextLabel?.text = String(room_info["active_users"].intValue) + " Users"
        }
        else {
            cell!.textLabel?.text = "Oh noes! There's no rooms!"
            cell!.detailTextLabel?.text = "Why not create one?"
        }
        
        cell!.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
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
        
        if self.noRoomsToShow == false {
            cell!.contentView.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05)
            
            self.selectedRoom_info = self.rooms[indexPath.row]
            self.performSegueWithIdentifier("roomSegue", sender: nil)
        }
    }


}

