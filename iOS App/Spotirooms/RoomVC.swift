//
//  RoomVC.swift
//  Spotirooms
//
//  Created by Myles Ringle on 29/08/2015.
//  Copyright (c) 2015 Myles Ringle. All rights reserved.
//

import UIKit
import MediaPlayer
import SwiftyJSON
import DTIActivityIndicator
import WebImage

class RoomVC: UIViewController, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, MCBroadcastDelegate {
    
    let appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let userDefaults = NSUserDefaults.standardUserDefaults()
    weak var tabBarC: TabBarC!
    @IBOutlet weak var behindStatusBarView: UIView!
    @IBOutlet weak var customNavBar: UINavigationBar!
    @IBOutlet weak var customNavItem: UINavigationItem!
    var minimiseButton: UIBarButtonItem!
    var isClosing: Bool! = false
    var invalidSession: Bool! = false
    
    @IBOutlet weak var loadingCoverView: UIView!
    var myActivityIndicatorView: DTIActivityIndicatorView!
    var joinedRoom: Bool! = false
    var playerConnected: Bool! = false
    var timeoutTimer: NSTimer!
    var canStartPlaying: Bool! = false
    var currentTrackStartTime: NSTimeInterval! = 0.0
    
    var searchBar: UISearchBar!
    var searchActive: Bool = false
    var didPrevHaveResults: Bool = false
    var storedLeftBarButtons: [AnyObject]!
    var storedRightBarButtons: [AnyObject]!
    
    @IBOutlet weak var secondaryTitle: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    var track_uris = [NSURL]()
    var roomTrackData = [NSDictionary]()
    var searchResultData = [NSObject]()
    var loadingMoreResults: Bool = false
    var shown_listPage: SPTListPage!
    var noTracksToShow: Bool = true
    var autoReturningFromSearch: Bool = false
    var addingTrack: Bool = false
    
    @IBOutlet weak var currentInfoView: UIView!
    @IBOutlet weak var minimised_artworkView: UIImageView!
    @IBOutlet weak var minimised_roomNameField: UILabel!
    @IBOutlet weak var minimised_titleField: UILabel!
    
    @IBOutlet weak var progressView: UIProgressView?
    var trackProgressTimer: NSTimer?
    
    @IBOutlet weak var backgroundImageViewTop: UIImageView!
    @IBOutlet weak var artworkView: UIImageView!
    @IBOutlet weak var titleField: UILabel!
    @IBOutlet weak var artistField: UILabel!
    @IBOutlet weak var durationField: UILabel!
    @IBOutlet weak var starredButton: UIButton!
    var isStarred: Bool! = false
    
    var room_info: JSON!
    var socket: SocketIOClient!
    var player: SPTAudioStreamingController!
    
    var isPlaying: Bool! = false
    var isReplacingURIs: Bool! = false
    
    // Local sync stuff
    var ls_syncButton: UIBarButtonItem!
    var ls_Manager: MCBroadcast?
    var ls_Message: MCObject = MCObject()
    var ls_timeSyncWasPressed: NSTimeInterval!
    var ls_DeviceIsSlave: Bool! = false
    var ls_connected: Bool! = false
    var netAssoc: NetAssociation!
    var ls_currentTrackStartTime: NSTimeInterval = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Handling data
        let room_dict = self.room_info.dictionaryValue
        self.customNavItem.title = room_info["name"].stringValue
        self.minimised_roomNameField.text = room_info["name"].stringValue
        self.secondaryTitle.text = "     UPCOMING TRACKS"
        
        // Setup nav bar
        self.customNavBar.tintColor = UIColor.whiteColor()
        self.minimiseButton = UIBarButtonItem(image: UIImage(named: "Room-Dismiss"), style: UIBarButtonItemStyle.Plain, target: self, action: "pressedMinimiseButton")
        self.customNavItem.leftBarButtonItems?.append(self.minimiseButton)
        self.ls_syncButton = UIBarButtonItem(image: UIImage(named: "Sync-Button"), style: UIBarButtonItemStyle.Plain, target: self, action: "pressedSyncButton")
        self.customNavItem.rightBarButtonItems?.append(self.ls_syncButton)
        self.storedLeftBarButtons = self.customNavItem.leftBarButtonItems
        self.storedRightBarButtons = self.customNavItem.rightBarButtonItems
        self.customNavItem.leftBarButtonItem?.enabled = false
        self.minimiseButton.enabled = false
        self.customNavItem.rightBarButtonItem?.enabled = false
        self.ls_syncButton.enabled = false
        
        self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissMode.OnDrag
        
        // Setup search bar
        self.searchBar = UISearchBar()
        self.searchBar.delegate = self
        self.searchBar.searchBarStyle = UISearchBarStyle.Default
        self.searchBar.barStyle = UIBarStyle.Black
        self.searchBar.tintColor = UIColor.whiteColor()
        self.searchBar.sizeToFit()
        
        // Changes text input to be white
        var textFieldInsideSearchBar = self.searchBar.valueForKey("searchField") as? UITextField
        textFieldInsideSearchBar?.textColor = UIColor.whiteColor()
        if textFieldInsideSearchBar!.respondsToSelector(Selector("attributedPlaceholder")) {
            var color = UIColor.lightGrayColor()
            let attributeDict = [NSForegroundColorAttributeName: UIColor.lightGrayColor()]
            textFieldInsideSearchBar!.attributedPlaceholder = NSAttributedString(string: "Search for Track", attributes: attributeDict)
        }
        //Get the glass icon
        var iconView: UIImageView = textFieldInsideSearchBar!.leftView as! UIImageView
        //Make the icon to a template which you can edit
        iconView.image = iconView.image?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        //Set the color of the icon
        iconView.tintColor = UIColor.lightGrayColor()
        
        // Sets this view controller as presenting view controller for the search interface
        definesPresentationContext = true
        
        self.socket = SocketIOClient(socketURL: Constants.socketURL, opts: [
            "nsp": "/spotirooms",
            "log": false,
            "forceWebsockets": true
        ])
        self.addHandlers()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Make progressView bigger since limited to 2px
        self.progressView!.transform = CGAffineTransformMakeScale(1.0, 4.0)
        
        // Put separator above first table cell, set background colour and change insets
        self.tableView.layoutMargins = UIEdgeInsetsMake(0, 16, 0, 0)
        self.tableView.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0).colorWithAlphaComponent(0.95)
        //self.tableView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.5)
        /*var line = CALayer()
        line.borderColor = self.tableView.separatorColor.CGColor
        line.borderWidth = 1
        line.frame = CGRectMake(16, 0, UIScreen.mainScreen().bounds.width-16, 1 / UIScreen.mainScreen().scale)
        self.tableView.layer.addSublayer(line)*/
        
        // Currently playing hide in case no tracks and sort artwork shadow
        self.durationField.hidden = true
        self.artworkView.layer.shadowColor = UIColor.blackColor().CGColor
        self.artworkView.layer.shadowOffset = CGSizeMake(0, 0)
        self.artworkView.layer.shadowOpacity = 0.7
        self.artworkView.layer.shadowRadius = 2.5
        self.minimised_artworkView.layer.shadowColor = UIColor.blackColor().CGColor
        self.minimised_artworkView.layer.shadowOffset = CGSizeMake(0, 0)
        self.minimised_artworkView.layer.shadowOpacity = 0.4
        self.minimised_artworkView.layer.shadowRadius = 2.0
        
        // Show activity indicator
        self.myActivityIndicatorView = DTIActivityIndicatorView(frame: CGRect(x:self.view.center.x-40, y:self.view.center.y-80, width:80.0, height:80.0))
        self.loadingCoverView.addSubview(self.myActivityIndicatorView)
        self.myActivityIndicatorView.indicatorColor = UIColor.whiteColor()
        self.myActivityIndicatorView.indicatorStyle = "spotify"
        self.myActivityIndicatorView.startActivity()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // Connect to server and Spotify
        self.socket.connect()
        self.handleNewSession()
        
        // Check we have connected within 25 secs or else timeout
        self.timeoutTimer = NSTimer.scheduledTimerWithTimeInterval(25.0, target: self, selector: "checkConnect", userInfo: nil, repeats: false)
    }
    
    // Hide the loading view after connecting
    func hideLoadingView() {
        if self.joinedRoom == true && self.playerConnected == true {
            self.myActivityIndicatorView.stopActivity(true)
            self.customNavItem.leftBarButtonItem?.enabled = true
            self.minimiseButton.enabled = true
            self.customNavItem.rightBarButtonItem?.enabled = true
            UIView.animateWithDuration(0.5, animations: {
                self.loadingCoverView.alpha = 0
                }, completion: { _ in
                    self.loadingCoverView.hidden = true
            })
        }
    }
    
    func tryToStartPlaying() {
        if self.canStartPlaying == true && self.joinedRoom == true {
            if self.noTracksToShow == false {
                self.startPlaying()
            }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        self.timeoutTimer.invalidate()
    }
    
    deinit {
        println("DEINIT")
        // Clear image cache when view is destroyed
        let imageManager = SDWebImageManager.sharedManager()
        imageManager.imageCache.clearMemory()
        imageManager.imageCache.cleanDisk()
    }
    
    // Check we are connected or else show timeout error
    func checkConnect() {
        if self.joinedRoom == false || self.playerConnected == false {
            println("*** Timeout error ***")
            var alert = UIAlertController(title: "Connection Error", message: "Connection timed out.", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
            self.presentViewController(alert, animated: true, completion: nil)
            self.myActivityIndicatorView.stopActivity(true)
        }
    }
    
    // Handle alert view actions
    func handleAlert(alert: UIAlertController, action: UIAlertAction) {
        if alert.title == "Connection Error" {
            if alert.message == "Invalid session." {
                self.invalidSession = true
            }
            switch action.style{
            case .Default:
                self.pressedCloseButton()
            case .Cancel:
                break
            case .Destructive:
                break
            }
        }
    }
    
    // Server socket handlers
    func addHandlers() {
        
        self.socket.on("connect") {data, ack in
            println("*** Socket Connected ***")
            self.socket.emit("join room", [
                "room_id": self.room_info["room_id"].intValue,
                "session_id": self.userDefaults.stringForKey("session_token")!
            ])
        }
        
        self.socket.on("join room success") {data, ack in
            var dict = data![0] as! NSDictionary
            var response: AnyObject! = dict["data"]
            
            if response as? String == "nil" {
                self.noTracksToShow = true
                self.joinedRoom = true
                self.hideLoadingView()
            }
            else {
                self.noTracksToShow = false
                self.durationField.hidden = false
                self.track_uris.removeAll()
                for item in (response as! NSArray) {
                    let track = item as! NSDictionary
                    self.roomTrackData.append(track)
                    self.track_uris.append(NSURL(string: track["track_id"] as! String)!)
                }
                
                // API IS LIMITED TO 50 - DO CONSECUTIVE CALLS
                var auth = SPTAuth.defaultInstance()
                SPTTrack.tracksWithURIs(self.track_uris, session: auth.session, callback: { (error: NSError!, searchResults: AnyObject!) -> Void in
                    
                    if error != nil {
                        println("*** Error retreiving tracklist: \(error)")
                        self.myActivityIndicatorView.stopActivity(true)
                        var alert = UIAlertController(title: "Connection Error", message: "Error retreiving tracklist.", preferredStyle: UIAlertControllerStyle.Alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
                        self.presentViewController(alert, animated: true, completion: nil)
                        return
                    }
                    
                    let all_tracks = searchResults as! NSArray
                    
                    for var i = 0; i < all_tracks.count; i++ {
                        let track = all_tracks[i] as! SPTTrack
                        self.roomTrackData[i].setValue(track, forKey: "SPTTrack")
                    }
                    
                    self.tableView.reloadData()
                    
                    println("*** Joined Room ***")
                    self.joinedRoom = true
                    self.hideLoadingView()
                    self.tryToStartPlaying()
                })
            }
        }
        
        self.socket.on("join room fail") {data, ack in
            var dict = data![0] as! NSDictionary
            var error: AnyObject! = dict["data"]
            
            println("*** Error joining room: \(error)")
            self.myActivityIndicatorView.stopActivity(true)
            var alert = UIAlertController(title: "Connection Error", message: (error as! String), preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
            self.presentViewController(alert, animated: true, completion: nil)
        }
        
        self.socket.on("start playing success") {data, ack in
            var dict = data![0] as! NSDictionary
            self.currentTrackStartTime = dict["start_time"] as! NSTimeInterval
            
            println("*** Can start playing ***")
            self.canStartPlaying = true
            
            if self.isPlaying == false {
                self.tryToStartPlaying()
            }
        }
        
        self.socket.on("add track success") {data, ack in
            var dict = data![0] as! NSDictionary
            var track_id: AnyObject! = dict["track_id"]
            
            self.customNavItem.leftBarButtonItem?.enabled = true
            self.durationField.hidden = false
            
            var auth = SPTAuth.defaultInstance()
            let track_uri = NSURL(string: track_id as! String)
            SPTTrack.trackWithURI(track_uri, session: auth.session, callback: { (error: NSError!, searchResults: AnyObject!) -> Void in
                
                if error != nil {
                    println("*** Error retrieving track after add: \(error)")
                    var alert = UIAlertController(title: "Error", message: "Error retrieving track information from Spotify.", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
                    self.presentViewController(alert, animated: true, completion: nil)
                    return
                }
                
                let track = searchResults as! SPTTrack
                self.searchResultData.removeAll()
                dict.setValue(track, forKey: "SPTTrack")
                self.roomTrackData.append(dict)
                
                if self.noTracksToShow == true {
                    self.noTracksToShow = false
                    self.getURIsAndStartPlaying()
                }
                else {
                    self.track_uris.append(track_uri!)
                    self.replaceURIsAndContinuePlaying()
                }
                
                self.autoReturningFromSearch = true
                self.pressedCancelButton()
                self.autoReturningFromSearch = false
                self.addingTrack = false
            })
            
        }
        
        self.socket.on("add track fail") {data, ack in
            var dict = data![0] as! NSDictionary
            var error: AnyObject! = dict["data"]
            if let selectedIndexPath: NSIndexPath = self.tableView.indexPathForSelectedRow() {
                var cell = self.tableView.cellForRowAtIndexPath(selectedIndexPath)
                cell!.contentView.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
            }
            self.addingTrack = false
            self.tableView.reloadData()
            
            println("*** Error adding track: \(error)")
            var title = "Error"
            if (error as! String) == "Invalid session." {
                title = "Connection Error"
            }
            var alert = UIAlertController(title: title, message: (error as! String), preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
            self.presentViewController(alert, animated: true, completion: nil)
        }
        
        self.socket.on("upvote track success") {data, ack in
            self.socket.emit("get tracklist", [
                "room_id": self.room_info["room_id"].intValue,
                "session_id": self.userDefaults.stringForKey("session_token")!
            ])
        }
        
        self.socket.on("tracklist update") {data, ack in
            var dict = data![0] as! NSDictionary
            var response: AnyObject! = dict["data"]
            
            self.handleNewUpvote(response)
        }
        
    }
    
    func handleNewSession() {
        var auth = SPTAuth.defaultInstance()
        
        if (self.player == nil) {
            self.player = SPTAudioStreamingController(clientId: auth.clientID)
            self.player.playbackDelegate = self
            self.player.diskCache = SPTDiskCache(capacity: 1024 * 1024 * 64)
        }
        
        self.player.loginWithSession(auth.session, callback: { (error: NSError!) -> Void in
            
            if error != nil {
                println("*** Error enabling playback: \(error)")
                self.myActivityIndicatorView.stopActivity(true)
                var alert = UIAlertController(title: "Connection Error", message: "Could not connect to Spotify.", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
                self.presentViewController(alert, animated: true, completion: nil)
                return
            }
            
            println("*** Player Connected ***")
            self.playerConnected = true
            self.hideLoadingView()
        })
    }
    
    func handleNewUpvote(response: AnyObject) {
        self.track_uris.removeAll()
        var temp_roomTrackData = [NSDictionary]()
        for item in (response as! NSArray) {
            let track = item as! NSDictionary
            temp_roomTrackData.append(track)
            self.track_uris.append(NSURL(string: track["track_id"] as! String)!)
        }
        self.roomTrackData = temp_roomTrackData
        
        // API IS LIMITED TO 50 - DO CONSECUTIVE CALLS
        var auth = SPTAuth.defaultInstance()
        SPTTrack.tracksWithURIs(self.track_uris, session: auth.session, callback: { (error: NSError!, searchResults: AnyObject!) -> Void in
            
            if error != nil {
                println("*** Error retreiving tracklist: \(error)")
                self.myActivityIndicatorView.stopActivity(true)
                var alert = UIAlertController(title: "Connection Error", message: "Error retreiving tracklist.", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
                self.presentViewController(alert, animated: true, completion: nil)
                return
            }
            
            let all_tracks = searchResults as! NSArray
            
            for var i = 0; i < all_tracks.count; i++ {
                let track = all_tracks[i] as! SPTTrack
                self.roomTrackData[i].setValue(track, forKey: "SPTTrack")
            }
            
            
            self.replaceURIsAndContinuePlaying()
            self.tableView.reloadData()
        })
    }
    
    @IBAction func pressedCloseButton() {
        self.timeoutTimer.invalidate()
        self.tabBarC.hideRoomViewForDestroy()
    }
    
    func closeRoom() {
        self.isClosing = true
        self.ls_stop()
        self.timeoutTimer.invalidate()
        self.stopProgressBarUpdate()
        // Disconnect from server
        self.socket.removeAllHandlers()
        self.socket.close(fast: false)
        println("*** Socket Disconnected ***")
        
        if self.player != nil {
            // Stop playback
            self.player.stop({ (error: NSError!) -> Void in
                if error != nil {
                    println("*** Error stopping playback: \(error)")
                }
                
                // Disconnect from Spotify
                self.player.logout({ (error: NSError!) -> Void in
                    if error != nil {
                        println("*** Error logging out of player: \(error)")
                    }
                    println("*** Player Disconnected ***")
                })
                // Remove room view
                self.tabBarC.removeRoomView()
            })
        }
    }
    
    func pressedMinimiseButton() {
        self.timeoutTimer.invalidate()
        self.tabBarC.minimiseRoom()
    }
    
    @IBAction func pressedSearchButton() {
        self.customNavItem.leftBarButtonItems = nil
        self.customNavItem.rightBarButtonItems = nil
        var cancelButton = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.Plain, target: self, action: "pressedCancelButton")
        self.customNavItem.rightBarButtonItem = cancelButton
        self.customNavItem.titleView = self.searchBar
        
        self.searchBar.becomeFirstResponder()
    }
    
    func pressedCancelButton() {
        if let selectedIndexPath: NSIndexPath = self.tableView.indexPathForSelectedRow() {
            var cell = tableView.cellForRowAtIndexPath(selectedIndexPath)
            cell!.contentView.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
        }
        
        self.tableView.tableFooterView = nil
        self.searchBar.text = nil
        self.customNavItem.hidesBackButton = false
        self.customNavItem.leftBarButtonItems = self.storedLeftBarButtons
        self.customNavItem.rightBarButtonItems = self.storedRightBarButtons
        self.customNavItem.titleView = nil
        
        self.searchBar(self.searchBar, textDidChange: "") // also calls table reload
        self.searchActive = false
    }
    
    @IBAction func pressedStarredButton() {
        if self.isStarred == false {
            self.starredButton.setImage(UIImage(named: "Starred"), forState: UIControlState.Normal)
            self.isStarred = true
        }
        else {
            self.starredButton.setImage(UIImage(named: "Unstarred"), forState: UIControlState.Normal)
            self.isStarred = false
        }
    }
    
    @IBAction func pressedUpvoteButton(sender: UIButton) {
        let timeLeft = self.player.currentTrackDuration-self.player.currentPlaybackPosition
        if timeLeft > 4 {
            let trackInfo = self.roomTrackData[sender.tag+1]
            let roomtrack_id = trackInfo["id"]!.stringValue.toInt()
            println("*** Upvoting track ***")
            self.socket.emit("upvote track", [
                "session_id": self.userDefaults.stringForKey("session_token")!,
                "room_id": self.room_info["room_id"].intValue,
                "roomtrack_id": roomtrack_id!
            ])
        }
    }
    
    
    func loadResults(searchTerm: String!) {
        var auth = SPTAuth.defaultInstance()
        
        SPTSearch.performSearchWithQuery(searchTerm,
            queryType: SPTSearchQueryType.QueryTypeTrack,
            accessToken: auth.session.accessToken,
            callback: { (error: NSError!, searchResults: AnyObject!) -> Void in
                
                if error != nil {
                    println("*** Error performing search: \(error)")
                    return
                }
                
                let listPage = searchResults as! SPTListPage
                
                if listPage.totalListLength == 0 {
                    if self.didPrevHaveResults == false {
                        self.searchResultData.removeAll()
                    }
                }
                else {
                    self.shown_listPage = listPage
                    
                    // Remove old data here so that if new search is nil we still have old results
                    self.didPrevHaveResults = true
                    self.searchResultData.removeAll()
                    
                    self.processNewResults(listPage)

                }
                self.tableView!.reloadData()
        })

    }
    
    func loadMoreResults() {
        if self.loadingMoreResults == false {
            self.loadingMoreResults = true
            var footerView = UIView(frame: CGRectMake(0, 0, self.tableView.bounds.width, 45))
            var activityIndicator = UIActivityIndicatorView(frame: CGRectMake(self.tableView.center.x-10, 10, 20, 20)) as UIActivityIndicatorView
            activityIndicator.hidesWhenStopped = true
            activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.Gray
            footerView.addSubview(activityIndicator)
            self.tableView.tableFooterView = footerView
            activityIndicator.startAnimating()
            
            var auth = SPTAuth.defaultInstance()
            
            self.shown_listPage.requestNextPageWithAccessToken(auth.session.accessToken, callback:  { (error: NSError!, searchResults: AnyObject!) -> Void in
            
                if error != nil {
                    println("*** Error performing search: \(error)")
                    return
                }
                
                let listPage = searchResults as! SPTListPage
                self.shown_listPage = listPage
                
                self.processNewResults(listPage)
                activityIndicator.stopAnimating()
                self.tableView!.reloadData()
                self.loadingMoreResults = false
            })
        }
    }
    
    func processNewResults(listPage: SPTListPage) {
        for item in listPage.items {
            let partialTrack = item as! SPTPartialTrack
            self.searchResultData.append(partialTrack)
        }
        
        if listPage.hasNextPage == false {
            var endOfResults = UILabel(frame: CGRectMake(self.tableView.center.x-50, 0, 100, 40))
            endOfResults.text = "- END OF RESULTS -"
            endOfResults.font = UIFont(name: "HelveticaNeue-Light", size: 11)
            endOfResults.textColor = UIColor.lightGrayColor()
            self.tableView.tableFooterView = endOfResults
        }
        else {
            self.tableView.tableFooterView = nil
        }
    }
    
    func stringFromTimeInterval(interval:NSTimeInterval) -> String {
        var ti = NSInteger(interval)
        
        //var ms = Int((interval % 1) * 1000)
        
        var seconds = ti % 60
        var minutes = (ti / 60) % 60
        var hours = (ti / 3600)
        
        if hours < 1 {
            return String(format: "%0.2d:%0.2d",minutes,seconds)
        }
        else {
            return String(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
        }
    }
    
    func startPlaying() {
        let startTime: NSTimeInterval = NSDate().timeIntervalSince1970 - self.currentTrackStartTime
        let playOptions: SPTPlayOptions = SPTPlayOptions()
        playOptions.startTime = startTime
        // API IS LIMITED TO 100 - DO CONSECUTIVE CALLS
        self.player.playURIs(self.track_uris, withOptions: playOptions, callback: { (error: NSError!) -> Void in
            if error != nil {
                println("*** Error playing tracks: \(error)")
                var alert = UIAlertController(title: "Error", message: "Problem starting playback.", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
                self.presentViewController(alert, animated: true, completion: nil)
                return
            }
        })
    }
    
    func unPause() {
        self.endOfTrack()
        self.getURIsAndStartPlaying()
    }
    
    func endOfTrack() {
        self.roomTrackData.removeAtIndex(0)
        if self.roomTrackData.count == 0 {
            self.noTracksToShow = true
        }
        if self.searchActive == false {
            self.tableView.reloadData()
        }
    }
    
    func getURIsAndStartPlaying() {
        self.track_uris.removeAll()
        for item in self.roomTrackData {
            let track = item["SPTTrack"] as! SPTPartialTrack
            self.track_uris.append(track.playableUri)
        }
        self.startPlaying()
    }
    
    func replaceURIsAndContinuePlaying() {
        self.isReplacingURIs = true
        self.player.replaceURIs(self.track_uris, withCurrentTrack: 0, callback: { (error: NSError!) -> Void in
            self.isReplacingURIs = false
            if error != nil {
                println("*** Error replacing track URIs: \(error)")
                return
            }
        })
    }
    
    func startProgressBarUpdate() {
        self.trackProgressTimer = NSTimer.scheduledTimerWithTimeInterval(1.5, target: self, selector: "updateProgressBar", userInfo: nil, repeats: true)
    }
    
    func updateProgressBar() {
        let progress = Float(self.player.currentPlaybackPosition/self.player.currentTrackDuration)
        self.progressView!.setProgress(progress, animated: false)
    }
    
    func stopProgressBarUpdate() {
        if trackProgressTimer != nil {
            self.trackProgressTimer!.invalidate()
        }
    }
    
    ////////////////////////////////////////////////////////////
    // UITableViewDataSource methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Handle currently playing view
        if self.noTracksToShow == false {
            self.starredButton.hidden = false
            
            let track = self.roomTrackData[0]
            let partialTrack = track["SPTTrack"] as! SPTTrack
            
            var artistName = ""
            for artist in partialTrack.artists {
                let partialArtist = artist as! SPTPartialArtist
                if artistName == "" {
                    artistName = partialArtist.name
                }
                else {
                    artistName += ", \(partialArtist.name)"
                }
            }
            
            // Set label fields and artwork border
            self.titleField.text = partialTrack.name
            self.artistField.text = artistName
            self.durationField.text = self.stringFromTimeInterval(partialTrack.duration)
            if let imageURL = partialTrack.album?.largestCover?.imageURL {
                self.artworkView.sd_setImageWithURL(imageURL,
                    placeholderImage: UIImage(named: "Artwork-Placeholder"),
                    completed: { (image: UIImage!, error: NSError!, cacheType: SDImageCacheType, imageURL: NSURL!) in
                        
                        if error != nil {
                            println("*** Error downloading image: \(error)")
                            return
                        }
                        
                        if image != nil && cacheType == SDImageCacheType.None {
                            self.artworkView.alpha = 0.0
                            UIView.animateWithDuration(0.3, animations: {
                                self.artworkView.alpha = 1.0
                            })
                            if self.isPlaying == true {
                                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = [
                                    MPMediaItemPropertyArtist: self.artistField.text!,
                                    MPMediaItemPropertyTitle: self.titleField.text!,
                                    MPMediaItemPropertyArtwork: MPMediaItemArtwork(image: self.artworkView.image)
                                ]
                            }
                        }
                })
                self.minimised_artworkView.sd_setImageWithURL(imageURL,
                    placeholderImage: UIImage(named: "Artwork-Placeholder"),
                    completed: { (image: UIImage!, error: NSError!, cacheType: SDImageCacheType, imageURL: NSURL!) in
                        
                        if error != nil {
                            println("*** Error downloading image: \(error)")
                            return
                        }
                        
                        if image != nil && cacheType == SDImageCacheType.None {
                            self.minimised_artworkView.alpha = 0.0
                            UIView.animateWithDuration(0.3, animations: {
                                self.minimised_artworkView.alpha = 1.0
                            })
                        }
                })
                self.backgroundImageViewTop.sd_setImageWithURL(imageURL,
                    placeholderImage: UIImage(named: "Artwork-Placeholder"),
                    completed: { (image: UIImage!, error: NSError!, cacheType: SDImageCacheType, imageURL: NSURL!) in
                        
                        if error != nil {
                            println("*** Error downloading image: \(error)")
                            return
                        }
                        
                        if image != nil && cacheType == SDImageCacheType.None {
                            self.backgroundImageViewTop.alpha = 0.0
                            UIView.animateWithDuration(0.3, animations: {
                                self.backgroundImageViewTop.alpha = 1.0
                            })
                        }
                })
            }
        }
        else if self.noTracksToShow == true {
            self.starredButton.hidden = true
            self.durationField.hidden = true
            
            self.titleField.text = "Oh noes! There's no tracks!"
            self.artistField.text = "Why not add one?"
            self.artworkView.image = UIImage(named: "No-Tracks-Placeholder")
        }
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count = 1
        if self.searchActive == true && self.searchResultData.count > 0 {
            count = self.searchResultData.count
        }
        else if self.noTracksToShow == false {
            count = self.roomTrackData.count == 1 ? self.roomTrackData.count : self.roomTrackData.count-1
        }
        return count
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 62
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // IN SEARCH
        if self.searchActive {
            // IN SEARCH WITH RESULTS TO SHOW
            if self.searchResultData.count > 0 {
                var cell = tableView.dequeueReusableCellWithIdentifier("SearchResultCell") as? SearchResultCell
                
                if cell == nil {
                    cell = SearchResultCell()
                }
                
                if let coverView = cell!.artworkView.viewWithTag(1) {
                    coverView.removeFromSuperview()
                }
                if let activityIndicator = cell!.artworkView.viewWithTag(2) {
                    activityIndicator.removeFromSuperview()
                }
                
                let partialTrack = self.searchResultData[indexPath.row] as! SPTPartialTrack
                
                var artistName = ""
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                    for artist in partialTrack.artists {
                        let partialArtist = artist as! SPTPartialArtist
                        if artistName == "" {
                            artistName = partialArtist.name
                        }
                        else {
                            artistName += ", \(partialArtist.name)"
                        }
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        cell!.artistField.text = artistName
                    })
                })
                
                // Set label fields and artwork border
                cell!.titleField.text = partialTrack.name
                if let imageURL = partialTrack.album?.smallestCover?.imageURL {
                    cell!.artworkView.sd_setImageWithURL(imageURL,
                        placeholderImage: UIImage(named: "Artwork-Placeholder"),
                        //options: SDWebImageOptions.CacheMemoryOnly,
                        completed: { (image: UIImage!, error: NSError!, cacheType: SDImageCacheType, imageURL: NSURL!) in
                            
                            if error != nil {
                                println("*** Error downloading image: \(error)")
                                return
                            }
                            
                            if image != nil && cacheType == SDImageCacheType.None {
                                cell!.artworkView.alpha = 0.0;
                                UIView.animateWithDuration(0.3, animations: {
                                    cell!.artworkView.alpha = 1.0
                                })
                            }
                    })
                }
                cell!.artworkView.layer.shadowColor = UIColor.blackColor().CGColor
                cell!.artworkView.layer.shadowOffset = CGSizeMake(0, 0)
                cell!.artworkView.layer.shadowOpacity = 0.4
                cell!.artworkView.layer.shadowRadius = 2.0
                
                if self.shown_listPage != nil {
                    if indexPath.row == self.searchResultData.count-1 && self.shown_listPage.hasNextPage == true {
                        self.loadMoreResults()
                    }
                }
                
                cell!.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
                cell!.selectionStyle = UITableViewCellSelectionStyle.None
                
                return cell!
            }
            // IN SEARCH BUT NO RESULTS TO SHOW
            else {
                var cell = tableView.dequeueReusableCellWithIdentifier("cell") as? UITableViewCell
                
                if cell == nil {
                    cell = UITableViewCell(style: UITableViewCellStyle.Value1, reuseIdentifier: "cell")
                }
                
                cell!.textLabel?.text = "No results found."
                cell!.detailTextLabel?.text = ""
                
                cell!.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
                cell!.textLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 16)
                cell!.textLabel?.textColor = UIColor.whiteColor()
                cell!.detailTextLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 13)
                cell!.detailTextLabel?.textColor = UIColor.lightGrayColor()
                cell!.selectionStyle = UITableViewCellSelectionStyle.None
                
                return cell!
            }
        }
        // IN ROOM TRACKLIST BUT EITHER ONLY 1 TRACK OR NO TRACKS TO SHOW
        else if self.noTracksToShow == true || self.roomTrackData.count == 1 {
            var cell = tableView.dequeueReusableCellWithIdentifier("cell") as? UITableViewCell
            
            if cell == nil {
                cell = UITableViewCell(style: UITableViewCellStyle.Value1, reuseIdentifier: "cell")
            }
            
            cell!.textLabel?.text = "No tracks in playlist."
            cell!.detailTextLabel?.text = ""
            
            //cell!.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
            cell!.backgroundColor = UIColor.clearColor()
            cell!.textLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 16)
            cell!.textLabel?.textColor = UIColor.lightGrayColor()
            cell!.detailTextLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 13)
            cell!.detailTextLabel?.textColor = UIColor.groupTableViewBackgroundColor()
            cell!.selectionStyle = UITableViewCellSelectionStyle.None
            
            if let progressView = self.progressView {
                progressView.setProgress(0, animated: false)
            }
            
            return cell!
        }
        // IN ROOM TRACKLIST AND SHOWING TRACKS
        else {
            var cell = tableView.dequeueReusableCellWithIdentifier("TrackListCell") as? TrackListCell
            
            if cell == nil {
                cell = TrackListCell()
            }
            
            if let coverView = cell!.artworkView.viewWithTag(1) {
                coverView.removeFromSuperview()
            }
            if let activityIndicator = cell!.artworkView.viewWithTag(2) {
                activityIndicator.removeFromSuperview()
            }
            
            let track = self.roomTrackData[indexPath.row+1]
            let partialTrack = track["SPTTrack"] as! SPTTrack
            
            var artistName = ""
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                for artist in partialTrack.artists {
                    let partialArtist = artist as! SPTPartialArtist
                    if artistName == "" {
                        artistName = partialArtist.name
                    }
                    else {
                        artistName += ", \(partialArtist.name)"
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    cell!.artistField.text = artistName
                })
            })
            
            // Set label fields and artwork border
            cell!.playNumber.text = String(indexPath.row+1)
            cell!.titleField.text = partialTrack.name
            cell!.durationField.text = self.stringFromTimeInterval(partialTrack.duration)
            if let imageURL = partialTrack.album?.largestCover?.imageURL {
                cell!.artworkView.sd_setImageWithURL(imageURL,
                    placeholderImage: UIImage(named: "Artwork-Placeholder"),
                    completed: { (image: UIImage!, error: NSError!, cacheType: SDImageCacheType, imageURL: NSURL!) in
                        
                        if error != nil {
                            println("*** Error downloading image: \(error)")
                            return
                        }
                        
                        if image != nil && cacheType == SDImageCacheType.None {
                            cell!.artworkView.alpha = 0.0;
                            UIView.animateWithDuration(0.3, animations: {
                                cell!.artworkView.alpha = 1.0
                            })
                        }

                })
                cell!.backgroundImageView.sd_setImageWithURL(imageURL,
                    completed: { (image: UIImage!, error: NSError!, cacheType: SDImageCacheType, imageURL: NSURL!) in
                        
                        if error != nil {
                            println("*** Error downloading image: \(error)")
                            return
                        }
                        
                        if image != nil && cacheType == SDImageCacheType.None {
                            cell!.backgroundImageView.alpha = 0.0
                            UIView.animateWithDuration(0.3, animations: {
                                cell!.backgroundImageView.alpha = 0.05
                            })
                        }
                        
                })
            }
            cell!.artworkView.layer.shadowColor = UIColor.blackColor().CGColor
            cell!.artworkView.layer.shadowOffset = CGSizeMake(0, 0)
            cell!.artworkView.layer.shadowOpacity = 0.4
            cell!.artworkView.layer.shadowRadius = 2.0
            cell!.upvoteButton.tag = indexPath.row
            cell!.upvoteButton.addTarget(self, action: "pressedUpvoteButton:", forControlEvents: UIControlEvents.TouchUpInside)
            let spotiroomsTrackInfo = self.roomTrackData[indexPath.row+1]
            cell!.upvoteButton.setTitle(spotiroomsTrackInfo["upvotes"]!.stringValue, forState: UIControlState.Normal)

            if indexPath.row == 0 {
                cell!.upvoteButton.setBackgroundImage(UIImage(named: "Upvote-Background-Blue"), forState: UIControlState.Normal)
                cell!.upvoteButton.userInteractionEnabled = false
            }
            else if spotiroomsTrackInfo["has_upvoted"]!.intValue == 1 {
                cell!.upvoteButton.setBackgroundImage(UIImage(named: "Upvote-Background-Gold"), forState: UIControlState.Normal)
                cell!.upvoteButton.userInteractionEnabled = false
            }
            else {
                cell!.upvoteButton.setBackgroundImage(UIImage(named: "Upvote-Background"), forState: UIControlState.Normal)
                cell!.upvoteButton.userInteractionEnabled = true
            }
            
            //cell!.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
            cell!.backgroundColor = UIColor.clearColor()
            cell!.selectionStyle = UITableViewCellSelectionStyle.None
            
            return cell!
        }
        
    }
    
    ////////////////////////////////////////////////////////////
    // UITableViewDelegate methods
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var cell = tableView.cellForRowAtIndexPath(indexPath) as? SearchResultCell
        
        if self.searchActive == true && self.searchResultData.count > 0 && self.addingTrack == false {
            cell!.contentView.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05)
            
            var coverView = UIView(frame: CGRectMake(0, 0, cell!.artworkView.bounds.width, cell!.artworkView.bounds.height))
            coverView.tag = 1
            coverView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.7)
            cell!.artworkView.addSubview(coverView)
            var activityIndicator = DTIActivityIndicatorView(frame: CGRectMake(0, 0, cell!.artworkView.bounds.width, cell!.artworkView.bounds.height))
            activityIndicator.tag = 2
            cell!.artworkView.addSubview(activityIndicator)
            activityIndicator.indicatorColor = UIColor.whiteColor()
            activityIndicator.indicatorStyle = "spotify"
            activityIndicator.startActivity()
            
            self.addingTrack = true // to prevent selection of other cells
            self.customNavItem.leftBarButtonItem?.enabled = false
            
            let partialTrack = self.searchResultData[indexPath.row] as! SPTPartialTrack
            
            // Temp fix to prevent issues with replacingURIsPlaylist with spotify in final seconds of last song
            let timeLeft = self.player.currentTrackDuration-self.player.currentPlaybackPosition
            if self.roomTrackData.count == 1 && (timeLeft < 5) {
                let delay = (timeLeft+1) * Double(NSEC_PER_SEC)
                let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
                dispatch_after(time, dispatch_get_main_queue()) {
                    println("*** Adding track ***")
                    self.socket.emit("add track", [
                        "room_id": self.room_info["room_id"].intValue,
                        "session_id": self.userDefaults.stringForKey("session_token")!,
                        "track_id": partialTrack.playableUri.absoluteString!,
                        "track_duration": partialTrack.duration
                        ])
                }
            }
            else {
                println("*** Adding track ***")
                self.socket.emit("add track", [
                    "room_id": self.room_info["room_id"].intValue,
                    "session_id": self.userDefaults.stringForKey("session_token")!,
                    "track_id": partialTrack.playableUri.absoluteString!,
                    "track_duration": partialTrack.duration
                    ])
            }
        }
    }
    
    func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        var cell = tableView.cellForRowAtIndexPath(indexPath)
        
        if self.searchActive == true && self.addingTrack == false {
            cell!.contentView.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
        }
    }
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        if self.searchActive == false {
            self.pressedCancelButton()
        }
    }
    
    ////////////////////////////////////////////////////////////
    // UISearchBar Delegates
    
    func searchBar(searchBar: UISearchBar, textDidChange searchTerm: String) {
        
        self.tableView.tableFooterView = nil
        
        if count(searchTerm) > 0 {
            if self.searchActive == false {
                self.slideUpForResults()
            }
            self.searchActive = true
            self.secondaryTitle.text = "     SEARCH RESULTS"
            self.loadResults(searchTerm)
        }
        else if self.autoReturningFromSearch == true {
            if self.searchActive == true {
                self.slideDownForTracklist()
            }
            self.didPrevHaveResults = false
            self.searchActive = false
            self.secondaryTitle.text = "     UPCOMING TRACKS"
            self.tableView!.reloadData()
        }
        else {
            if self.searchActive == true {
                self.slideDownForTracklist()
            }
            self.didPrevHaveResults = false
            self.searchResultData.removeAll() // clear old data first
            self.searchActive = false
            self.secondaryTitle.text = "     UPCOMING TRACKS"
            self.tableView!.reloadData()
        }
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        self.searchBar.resignFirstResponder()
    }
    
    func slideUpForResults() {
        UIView.animateWithDuration(0.25, animations: { () -> Void in
            self.view.transform = CGAffineTransformMakeTranslation(0, -88)
            self.behindStatusBarView.transform = CGAffineTransformMakeTranslation(0, 88)
            self.customNavBar.transform = CGAffineTransformMakeTranslation(0, 88)
            }, completion: { _ in
                var largerFrame = self.view.frame
                largerFrame.size.height += 88
                self.view.frame = largerFrame
        })
    }
    
    func slideDownForTracklist() {
        UIView.animateWithDuration(0.25, animations: { () -> Void in
            self.view.transform = CGAffineTransformMakeTranslation(0, 0)
            self.behindStatusBarView.transform = CGAffineTransformMakeTranslation(0, 0)
            self.customNavBar.transform = CGAffineTransformMakeTranslation(0, 0)
            }, completion: { _ in
                var smallerFrame = self.view.frame
                smallerFrame.size.height -= 88
                self.view.frame = smallerFrame
        })
    }
    
    ////////////////////////////////////////////////////////////
    // Track Player Delegates
    
    func audioStreaming(audioStreaming: SPTAudioStreamingController!, didReceiveMessage message: String!) {
        var alert = UIAlertController(title: "Message from Spotify", message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func audioStreaming(audioStreaming: SPTAudioStreamingController!, didFailToPlayTrack trackUri: NSURL!) {
        println("*** Error playing track: \(trackUri)")
        /*self.player.stop(nil)
        // Wait till what would be end of track, then play again
        self.timeoutTimer = NSTimer.scheduledTimerWithTimeInterval(self.player.currentTrackDuration, target: self, selector: "unPause", userInfo: nil, repeats: false)*/
    }
    
    func audioStreaming(audioStreaming: SPTAudioStreamingController!, didChangePlaybackStatus isPlaying: Bool) {
        self.isPlaying = isPlaying
        println("*** Playing: \(isPlaying)")
        if isPlaying == true {
            self.startProgressBarUpdate()
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = [
                MPMediaItemPropertyArtist: self.artistField.text!,
                MPMediaItemPropertyTitle: self.titleField.text!,
                MPMediaItemPropertyArtwork: MPMediaItemArtwork(image: self.artworkView.image)
            ]
            self.ls_syncButton.enabled = true
        }
        else {
            self.stopProgressBarUpdate()
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = nil
            self.ls_syncButton.enabled = false
        }
    }
    
    func audioStreaming(audioStreaming: SPTAudioStreamingController!, didChangeToTrack trackMetadata: [NSObject : AnyObject]!) {
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = [
            MPMediaItemPropertyArtist: self.artistField.text!,
            MPMediaItemPropertyTitle: self.titleField.text!,
            MPMediaItemPropertyArtwork: MPMediaItemArtwork(image: self.artworkView.image)
        ]
    }
    
    func audioStreaming(audioStreaming: SPTAudioStreamingController!, didStartPlayingTrack trackUri: NSURL!) {
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = [
            MPMediaItemPropertyArtist: self.artistField.text!,
            MPMediaItemPropertyTitle: self.titleField.text!,
            MPMediaItemPropertyArtwork: MPMediaItemArtwork(image: self.artworkView.image)
        ]
        self.ls_currentTrackStartTime = NSDate().timeIntervalSince1970
        var timeWeShouldBeAt: NSTimeInterval = NSDate().timeIntervalSince1970 - self.currentTrackStartTime
        if timeWeShouldBeAt < self.player.currentPlaybackPosition-2
            || (timeWeShouldBeAt > self.player.currentPlaybackPosition+2 && timeWeShouldBeAt < self.player.currentPlaybackPosition+5) {
            timeWeShouldBeAt = NSDate().timeIntervalSince1970 - self.currentTrackStartTime
            self.player.seekToOffset(timeWeShouldBeAt, callback: nil)
            println("*** Audio out of sync - resyncing ***")
        }
        // Attempt Local sync
        self.ls_tryToSync()
    }
    
    func audioStreaming(audioStreaming: SPTAudioStreamingController!, didStopPlayingTrack trackUri: NSURL!) {
        if self.isClosing == false && self.isReplacingURIs == false {
            println("*** End of current track ***")
            self.endOfTrack()
        }
    }
    
    // Lost internet conncetion
    func audioStreamingDidDisconnect(audioStreaming: SPTAudioStreamingController!) {
        var alert = UIAlertController(title: "Connection Error", message: "Lost connection to Spotify.", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    
    //MARK: MCBroadcast delegate
    
    func ls_tryToSync() {
        let delay = 2 * Double(NSEC_PER_SEC)
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue()) {
            if let ls_Manager = self.ls_Manager {
                if self.ls_connected == true && self.ls_DeviceIsSlave == false {
                    
                    self.ls_Message.text = "\(self.appDelegate.nc.networkTime.timeIntervalSince1970+(self.player.currentTrackDuration-self.player.currentPlaybackPosition))"
                    //self.ls_Message.text = self.ls_currentTrackStartTime.description
                    self.ls_Manager!.sendObject(self.ls_Message, toBroadcasters: nil)
                }
            }
        }
    }
    
    func ls_stop() {
        if let ls_Manager = self.ls_Manager {
            ls_Manager.stopBrowsing()
            ls_Manager.stopAdvertising()
        }
    }
    
    func pressedSyncButton() {
        self.ls_syncButton.enabled = false
        //var nt: NSTimeInterval = appDelegate.nc.networkTime.timeIntervalSince1970
        //self.ls_timeSyncWasPressed = NSDate().timeIntervalSince1970
        self.ls_Manager = MCBroadcast(displayName: UIDevice.currentDevice().name, delegate: self)
        self.ls_Manager!.startBrowsing()
        self.ls_Manager!.startAdvertising()
    }
    
    func mcBroadcast(manager: MCBroadcast, broadcaster: MCBroadcaster, didChangeState state: MCBroadcastSessionState) {
        
        var status: String
        
        switch state {
        case .Connected:
            self.ls_syncButton = UIBarButtonItem(image: UIImage(named: "Sync-Button"), style: UIBarButtonItemStyle.Plain, target: self, action: "ls_tryToSync")
            self.ls_connected = true
            status = "Connected to \(broadcaster.displayName)"
            self.ls_tryToSync()
            break
            
        case .Connecting:
            self.ls_connected = false
            status = "Connecting to \(broadcaster.displayName)"
            break
            
        case .NotConnected:
            self.ls_syncButton.enabled = true
            self.ls_syncButton = UIBarButtonItem(image: UIImage(named: "Sync-Button"), style: UIBarButtonItemStyle.Plain, target: self, action: "pressedSyncButton")
            self.ls_connected = false
            self.ls_DeviceIsSlave = false
            status = "Not connected to \(broadcaster.displayName)"
            break
        }
        
        NSOperationQueue.mainQueue().addOperationWithBlock { () -> Void in
            println(status)
        }
    }
    
    func mcBroadcast(manager: MCBroadcast, didReceiveObject object: MCObject?, fromBroadcaster broadcaster: MCBroadcaster) {
        //var messageArr = split(object?.text as! String) {$0 == ","}
        //var theirTime: NSTimeInterval = (messageArr[0] as NSString).doubleValue
        //var theirTrackPosition: NSTimeInterval = (messageArr[1] as NSString).doubleValue
        //var latency = self.appDelegate.nc.networkTime.timeIntervalSince1970 - theirTime
        //var myTrackPositionAtTheirTime = self.player.currentPlaybackPosition - latency
        //var difference = myTrackPositionAtTheirTime - theirTrackPosition
        var theirEndTime: NSTimeInterval = ((object?.text as! String) as NSString).doubleValue
        //var goToTime: NSTimeInterval = receivedStartTime - self.ls_currentTrackStartTime
        var timeRemaining = theirEndTime - self.appDelegate.nc.networkTime.timeIntervalSince1970
        self.player.seekToOffset(self.player.currentTrackDuration-timeRemaining+0.15, callback: nil)
        println("*** SYNCING ***")
    }
    
    func mcBroadcast(manager: MCBroadcast, foundBroadcaster broadcaster: MCBroadcaster) {
        
    }
    
    func mcBroadcast(manager: MCBroadcast, lostBroadcaster broadcaster: MCBroadcaster) {
        self.ls_stop()
        self.ls_syncButton.enabled = true
    }
    
    func mcBroadcast(manager: MCBroadcast, didReceiveInvitationFromBroadcaster broadcaster: MCBroadcaster) {
        println("Received invitation from \(broadcaster.displayName)")
        self.ls_DeviceIsSlave = true
    }
    
    func mcBroadcast(manager: MCBroadcast, didAcceptInvitationFromBroadcaster broadcaster: MCBroadcaster) {
        println("Accepted invitation from \(broadcaster.displayName)")
    }
    
    func mcBroadcast(manager: MCBroadcast, didEncounterError error: NSError) {
    }
    
}

