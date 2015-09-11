//
//  ChatView.swift
//  Spotirooms
//
//  Created by Myles Ringle on 07/09/2015.
//  Copyright (c) 2015 Myles Ringle. All rights reserved.
//

import UIKit

class ChatView: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var chat_containerView: UITableView!
    @IBOutlet weak var chat_tableView: UITableView!
    
    // UITableViewDataSource methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
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
        cell!.textLabel?.text = "Yehhhaaaa"

        /*if self.noRoomsToShow == false {
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
        cell!.selectionStyle = UITableViewCellSelectionStyle.None*/
        
        return cell!
    }

    
}
