//
//  TabBarC.swift
//  Spotirooms
//
//  Created by Myles Ringle on 02/09/2015.
//  Copyright (c) 2015 Myles Ringle. All rights reserved.
//

import UIKit
import SwiftyJSON
import DTIActivityIndicator

class TabBarC: UITabBarController, UITabBarDelegate {
    
    var theStoryboard: UIStoryboard!
    
    var discoverNavC: UINavigationController!
    weak var discoverVC: RoomListVC!
    var profileNavC: UINavigationController!
    weak var profileVC: ProfileVC!
    var theTabBar: UITabBar!
    
    var roomNavC: UINavigationController!
    weak var roomVC: RoomVC!
    var activeRoom: Bool! = false
    var tapGestureRecognizer: UITapGestureRecognizer!
    var roomMinimised: Bool! = false
    var transferToNewRoom: Bool! = false
    var store_selectedRoom_info: JSON?
    var store_fromView: Int?
    var invalidSession: Bool! = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.theStoryboard = UIStoryboard(name: "Main", bundle: nil)
        
        self.discoverNavC = self.viewControllers![0] as! UINavigationController
        self.discoverVC = discoverNavC.viewControllers.first as! RoomListVC
        let discoverTabBarItem = UITabBarItem(title: nil, image: UIImage(named: "Discover"), tag: 0)
        discoverTabBarItem.imageInsets = UIEdgeInsets(top: 5, left: 0, bottom: -5, right: 0)
        self.discoverVC.tabBarC = self
        
        self.profileNavC = self.viewControllers![1] as! UINavigationController
        self.profileVC = profileNavC.viewControllers.first as! ProfileVC
        let profileTabBarItem = UITabBarItem(title: nil, image: UIImage(named: "Profile"), tag: 1)
        profileTabBarItem.imageInsets = UIEdgeInsets(top: 5, left: 0, bottom: -5, right: 0)
        self.profileVC.tabBarC = self
        
        self.theTabBar = UITabBar(frame: CGRectMake(0, self.view.bounds.maxY-49, UIScreen.mainScreen().bounds.width, 49))
        self.theTabBar.barTintColor = UIColor(red: 0.129, green: 0.1393, blue: 0.1514, alpha: 1.0)
        self.theTabBar.tintColor = UIColor.whiteColor()
        self.theTabBar.translucent = false
        self.theTabBar.items = [discoverTabBarItem, profileTabBarItem]
        self.theTabBar.selectedItem = discoverTabBarItem
        self.theTabBar.delegate = self
        
        self.tabBar.hidden = true
        
        self.view.addSubview(self.theTabBar)
    }
    
    func addRoomView(selectedRoom_info: JSON, fromView: Int) {
        if roomVC == nil {
            self.roomNavC = self.theStoryboard.instantiateViewControllerWithIdentifier("RoomNavC") as! UINavigationController
            self.roomVC = roomNavC!.viewControllers.first as! RoomVC
            self.discoverVC.selectedRoom_info = selectedRoom_info
            self.profileVC.selectedRoom_info = selectedRoom_info
            roomVC.room_info = selectedRoom_info
            roomVC.tabBarC = self
            
            self.roomNavC.navigationBar.tintColor = UIColor.whiteColor()
            self.roomNavC.view.layer.shadowOpacity = 0.3
            
            self.roomNavC.view.frame.origin.y = self.theTabBar.frame.minY
            UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: nil, animations: {
                self.view.insertSubview(self.roomNavC.view, belowSubview: self.theTabBar)
                self.roomNavC.view.frame.origin.y = 0
                self.theTabBar.transform = CGAffineTransformMakeTranslation(0, self.theTabBar.bounds.height)
                }, completion: { _ in
                    // Setup tap gesture recognizer for minimising
                    self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "handleTapGesture:")
                    self.tapGestureRecognizer.delegate = self
                    self.tapGestureRecognizer.cancelsTouchesInView = false
                    self.roomVC.currentInfoView.addGestureRecognizer(self.tapGestureRecognizer)
                    if fromView == 0 {
                        self.discoverVC.deselectCells()
                        self.discoverVC.tableView.userInteractionEnabled = true
                    }
                    else {
                        self.profileVC.deselectCells()
                        self.profileVC.curatedTableView.userInteractionEnabled = true
                        self.profileVC.recentTableView.userInteractionEnabled = true
                    }
                    self.discoverVC.navigationItem.rightBarButtonItem?.enabled = true
                    self.transferToNewRoom = false
            })
            
            self.activeRoom = true
        }
        else {
            self.transferToNewRoom = true
            self.store_selectedRoom_info = selectedRoom_info
            self.store_fromView = fromView
            if fromView == 0 {
                self.discoverVC.showLoadingCell()
            }
            else {
                self.profileVC.showLoadingCell()
            }
            self.hideRoomViewForDestroy()
        }
    }
    
    
    override func tabBar(tabBar: UITabBar, didSelectItem item: UITabBarItem!) {
        if item.tag == 0 {
            self.selectedIndex = 0
        }
        else if item.tag == 1 {
            self.selectedIndex = 1
        }
    }
    
    func minimiseRoom() {
        if self.activeRoom == true {
            if self.selectedIndex == 0 {
                self.discoverVC.loadRoomList()
            }
            else if self.selectedIndex == 1 {
                self.profileVC.loadCuratedRoomList()
                self.profileVC.loadRecentRoomList()
            }
            UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: nil, animations: {
                self.roomNavC.view.transform = CGAffineTransformMakeTranslation(0, self.view.frame.maxY-self.theTabBar.bounds.height-64)
                self.roomVC.customNavBar.alpha = 0
                self.roomVC.behindStatusBarView.alpha = 0
                self.theTabBar.transform = CGAffineTransformMakeTranslation(0, 0)
                }, completion: { _ in
                    self.roomNavC.navigationBar.hidden = true
                    self.roomMinimised = true
            })
        }
    }
    
    func maximiseRoom() {
        if self.activeRoom == true {
            self.roomNavC.navigationBar.alpha = 0
            self.roomNavC.navigationBar.hidden = false
            UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: nil, animations: {
                self.roomNavC.view.transform = CGAffineTransformMakeTranslation(0, 0)
                self.roomVC.customNavBar.alpha = 1
                self.roomVC.behindStatusBarView.alpha = 1
                self.theTabBar.transform = CGAffineTransformMakeTranslation(0, self.theTabBar.bounds.height)
                }, completion: { _ in
                    self.roomMinimised = false
            })
        }
    }
    
    func hideRoomViewForDestroy() {
        if self.activeRoom == true {
            UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: nil, animations: {
                self.roomNavC.view.transform = CGAffineTransformMakeTranslation(0, self.view.frame.maxY)
                self.theTabBar.transform = CGAffineTransformMakeTranslation(0, 0)
                }, completion: { _ in
                    if self.roomVC.invalidSession == true {
                        self.invalidSession = true
                    }
                    self.roomVC.closeRoom()
            })
        }
    }
    
    func removeRoomView() {
        if self.activeRoom == true {
            if self.transferToNewRoom == false {
                self.discoverVC.selectedRoom_info = nil
                self.profileVC.selectedRoom_info = nil
                if self.selectedIndex == 0 {
                    self.discoverVC.loadRoomList()
                }
                else if self.selectedIndex == 1 {
                    self.profileVC.loadCuratedRoomList()
                    self.profileVC.loadRecentRoomList()
                }
            }
            self.roomVC.removeFromParentViewController()
            self.roomNavC.removeFromParentViewController()
            self.roomVC = nil
            self.roomNavC = nil
            self.activeRoom = false
            
            if self.invalidSession == true {
                self.navigationController?.popToRootViewControllerAnimated(true)
            }
            else if self.transferToNewRoom == true {
                self.addRoomView(self.store_selectedRoom_info!, fromView: self.store_fromView!)
                self.store_selectedRoom_info = nil
                self.store_fromView = nil
            }
        }
    }
    
}

// Pullover gesture recognition methods
extension TabBarC: UIGestureRecognizerDelegate {
    
    func handleTapGesture(recognizer: UITapGestureRecognizer) {
        
        if self.roomMinimised == true {
            maximiseRoom()
        }
    }
    
}

