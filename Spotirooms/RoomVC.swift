//
//  RoomVC.swift
//  Spotirooms
//
//  Created by Myles Ringle on 29/08/2015.
//  Copyright (c) 2015 Myles Ringle. All rights reserved.
//

import UIKit
import SwiftyJSON
import DTIActivityIndicator
import WebImage

class RoomVC: UIViewController, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate, UITableViewDataSource, UITableViewDelegate, UISearchControllerDelegate, UISearchBarDelegate {
    
    let userDefaults = NSUserDefaults.standardUserDefaults()
    
    @IBOutlet weak var loadingCoverView: UIView!
    var myActivityIndicatorView: DTIActivityIndicatorView!
    var joinedRoom: Bool! = false
    var playerConnected: Bool! = false
    
    var searchController : UISearchController!
    var searchActive: Bool = false
    var didPrevHaveResults: Bool = false
    var storedAddButton: UIBarButtonItem!
    
    @IBOutlet weak var secondaryTitle: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    var roomTrackData = [NSObject]()
    var searchResultData = [NSObject]()
    var loadingMoreResults: Bool = false
    var shown_listPage: SPTListPage!
    var noTracksToShow: Bool = true
    var autoReturningFromSearch: Bool = false
    var addingTrack: Bool = false
    
    @IBOutlet weak var artworkView: UIImageView!
    @IBOutlet weak var titleField: UILabel!
    @IBOutlet weak var artistField: UILabel!
    @IBOutlet weak var durationField: UILabel!
    
    var room_info: JSON!
    let socket = SocketIOClient(socketURL: Constants.socketURL, opts: [
        "nsp": "/spotirooms",
        "log": false
    ])
    var player: SPTAudioStreamingController!
    
    override func viewDidLoad() {
        self.storedAddButton = self.navigationItem.rightBarButtonItem
        self.navigationItem.rightBarButtonItem?.enabled = false
        
        // Setup search controller
        self.searchController = UISearchController(searchResultsController:  nil)
        self.searchController.delegate = self
        self.searchController.searchBar.delegate = self
        self.searchController.hidesNavigationBarDuringPresentation = false
        self.searchController.dimsBackgroundDuringPresentation = false
        self.searchController.searchBar.searchBarStyle = UISearchBarStyle.Default
        self.searchController.searchBar.barStyle = UIBarStyle.Black
        self.searchController.searchBar.tintColor = UIColor.whiteColor()
        self.searchController.searchBar.sizeToFit()
        
        // Changes text input to be white
        var textFieldInsideSearchBar = self.searchController.searchBar.valueForKey("searchField") as? UITextField
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
        
        // Handling data and setting up connections
        let room_dict = self.room_info.dictionaryValue
        self.title = room_info["name"].stringValue
        self.secondaryTitle.text = "NEXT"
        
        self.addHandlers()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Currently playing hide in case no tracks and sort artwork shadow
        self.durationField.hidden = true
        self.artworkView.layer.shadowColor = UIColor.blackColor().CGColor
        self.artworkView.layer.shadowOffset = CGSizeMake(0, 0)
        self.artworkView.layer.shadowOpacity = 0.7
        self.artworkView.layer.shadowRadius = 2.5
        
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
        
        // Check we have connected within 30 secs or else timeout
        var timer = NSTimer.scheduledTimerWithTimeInterval(30.0, target: self, selector: "checkConnect", userInfo: nil, repeats: false)
    }
    
    // Hide the loading view after connecting
    func hideLoadingView() {
        if self.joinedRoom == true && self.playerConnected == true {
            self.myActivityIndicatorView.stopActivity(true)
            self.navigationItem.rightBarButtonItem?.enabled = true
            UIView.animateWithDuration(0.5, animations: {
                self.loadingCoverView.alpha = 0
                }, completion: { _ in
                    self.loadingCoverView.hidden = true
            })
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        // Disconnect from server
        self.socket.close(fast: false)
        println("*** Socket Disconnected ***")
        
        // Disconnect from Spotify
        var auth = SPTAuth.defaultInstance()
        if self.player != nil {
            self.player.logout({ (error: NSError!) -> Void in
                if error != nil {
                    println("*** Error logging out of player: \(error)")
                }
                println("*** Player Disconnected ***")
            })
        }
    }
    
    // Clear image cache when view is destroyed
    deinit {
        let imageManager = SDWebImageManager.sharedManager()
        imageManager.imageCache.clearMemory()
        imageManager.imageCache.clearDisk()
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
            switch action.style{
            case .Default:
                self.navigationController?.popViewControllerAnimated(true)
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
                var track_uris = [NSURL]()
                for item in (response as! NSArray) {
                    let track = item as! NSDictionary
                    track_uris.append(NSURL(string: track["track_id"] as! String)!)
                }
                
                // API IS LIMITED TO 50 - DO CONSECUTIVE CALLS
                // *** Move the below to separate method and removeAll from filtered before running
                var auth = SPTAuth.defaultInstance()
                SPTTrack.tracksWithURIs(track_uris, session: auth.session, callback: { (error: NSError!, searchResults: AnyObject!) -> Void in
                    
                    if error != nil {
                        println("*** Error retreiving tracklist: \(error)")
                        self.myActivityIndicatorView.stopActivity(true)
                        var alert = UIAlertController(title: "Connection Error", message: "Error retreiving tracklist.", preferredStyle: UIAlertControllerStyle.Alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
                        self.presentViewController(alert, animated: true, completion: nil)
                        return
                    }
                    
                    let all_tracks = searchResults as! NSArray
                    
                    for item in all_tracks {
                        let track = item as! SPTTrack
                        self.roomTrackData.append(track)
                    }
                    
                    self.tableView.reloadData()
                    
                    self.joinedRoom = true
                    self.hideLoadingView()
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
        
        self.socket.on("add track success") {data, ack in
            var dict = data![0] as! NSDictionary
            var response: AnyObject! = dict["data"]
            
            self.noTracksToShow = false
            self.durationField.hidden = false
            
            var auth = SPTAuth.defaultInstance()
            let track_uri = NSURL(string: response as! String)
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
                self.roomTrackData.append(track)
                
                self.autoReturningFromSearch = true
                self.pressedCancelButton()
                self.autoReturningFromSearch = false
                self.addingTrack = false
            })
            
        }
        
        self.socket.on("add track fail") {data, ack in
            var dict = data![0] as! NSDictionary
            var error: AnyObject! = dict["data"]
            
            println("*** Error adding track: \(error)")
            var alert = UIAlertController(title: "Error", message: (error as! String), preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
            self.presentViewController(alert, animated: true, completion: nil)
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
    
    /*var playlistReq = SPTPlaylistSnapshot.createRequestForPlaylistWithURI(
        NSURL(string: "spotify:user:mylez:playlist:3tEfpz5C7uftjFYSN6ZTSc"),
        accessToken: auth.session.accessToken,
        error: nil
    )
    
    SPTRequest.sharedHandler().performRequest(playlistReq, callback: { (error: NSError!, response: NSURLResponse!, data: NSData!) -> Void in
        
        if error != nil {
            println("*** Error getting playlist: \(error)")
            return
        }
        
        var playlistSnapshot: SPTPlaylistSnapshot = SPTPlaylistSnapshot(fromData: data, withResponse: response, error: nil)
        
        self.player.playURIs(playlistSnapshot.firstTrackPage.items, fromIndex: 0, callback: nil)
    })*/
            
    
    @IBAction func pressedSearchButton() {
        self.navigationItem.hidesBackButton = true
        self.navigationItem.rightBarButtonItem = nil
        var cancelButton = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.Plain, target: self, action: "pressedCancelButton")
        self.navigationItem.rightBarButtonItem = cancelButton
        self.navigationItem.titleView = self.searchController.searchBar
                
        self.searchController.searchBar.becomeFirstResponder()
    }
    
    func pressedCancelButton() {
        if let selectedIndexPath: NSIndexPath = self.tableView.indexPathForSelectedRow() {
            var cell = tableView.cellForRowAtIndexPath(selectedIndexPath)
            cell!.contentView.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
        }
        
        self.tableView.tableFooterView = nil
        self.searchController.searchBar.text = nil
        self.navigationItem.hidesBackButton = false
        self.navigationItem.rightBarButtonItem = self.storedAddButton
        self.navigationItem.titleView = nil
        
        self.searchActive = false
        
        self.searchBar(self.searchController.searchBar, textDidChange: "") // also call table reload
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
        //var hours = (ti / 3600)
        
        return String(format: "%0.2d:%0.2d",minutes,seconds)
    }
    
    ////////////////////////////////////////////////////////////
    // UITableViewDataSource methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count = 1
        if self.searchActive == true && self.searchResultData.count > 0 {
            count = self.searchResultData.count
        }
        else if self.noTracksToShow == false {
            count = self.roomTrackData.count-1
        }
        return count
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 62
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        // Handle currently playing view
        if indexPath.row == 0 && self.noTracksToShow == false {
            let partialTrack = self.roomTrackData[indexPath.row] as! SPTTrack
            
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
            self.artworkView.sd_setImageWithURL(partialTrack.album.largestCover.imageURL,
                placeholderImage: UIImage(named: "Artwork-Placeholder"),
                completed: { (image: UIImage!, error: NSError!, cacheType: SDImageCacheType, imageURL: NSURL!) in
                    
                    if error != nil {
                        println("*** Error downloading image: \(error)")
                        return
                    }
                    
                    if image != nil && cacheType == SDImageCacheType.None {
                        self.artworkView.alpha = 0.0;
                        UIView.animateWithDuration(0.3, animations: {
                            self.artworkView.alpha = 1.0
                        })
                    }
            })
        }
        else if indexPath.row == 0 && self.noTracksToShow == true {
            self.durationField.hidden = true
            
            self.titleField.text = "Oh noes! There's no tracks!"
            self.artistField.text = "Why not add one?"
            self.artworkView.image = UIImage(named: "No-Tracks-Placeholder")
        }
        
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
                cell!.titleField.text = partialTrack.name
                cell!.artistField.text = artistName
                cell!.artworkView.sd_setImageWithURL(partialTrack.album.smallestCover.imageURL,
                    placeholderImage: UIImage(named: "Artwork-Placeholder"),
                    options: SDWebImageOptions.CacheMemoryOnly,
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
                cell!.artworkView.layer.shadowColor = UIColor.blackColor().CGColor
                cell!.artworkView.layer.shadowOffset = CGSizeMake(0, 0)
                cell!.artworkView.layer.shadowOpacity = 0.7
                cell!.artworkView.layer.shadowRadius = 2.5
                
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
        // IN ROOM TRACKLIST BUT NO TRACKS TO SHOW
        else if self.noTracksToShow == true {
            var cell = tableView.dequeueReusableCellWithIdentifier("cell") as? UITableViewCell
            
            if cell == nil {
                cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "cell")
            }
            
            cell!.textLabel?.text = ""
            cell!.detailTextLabel?.text = "Nothing to see here!"
            
            cell!.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
            cell!.textLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 16)
            cell!.textLabel?.textColor = UIColor.whiteColor()
            cell!.detailTextLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 13)
            cell!.detailTextLabel?.textColor = UIColor.lightGrayColor()
            cell!.selectionStyle = UITableViewCellSelectionStyle.None
            
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
            
            let partialTrack = self.roomTrackData[indexPath.row+1] as! SPTTrack
            
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
            cell!.titleField.text = partialTrack.name
            cell!.artistField.text = artistName
            cell!.durationField.text = self.stringFromTimeInterval(partialTrack.duration)
            cell!.artworkView.sd_setImageWithURL(partialTrack.album.smallestCover.imageURL,
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
            cell!.artworkView.layer.shadowColor = UIColor.blackColor().CGColor
            cell!.artworkView.layer.shadowOffset = CGSizeMake(0, 0)
            cell!.artworkView.layer.shadowOpacity = 0.7
            cell!.artworkView.layer.shadowRadius = 2.5
            
            cell!.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
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
            
            let partialTrack = self.searchResultData[indexPath.row] as! SPTPartialTrack
            self.socket.emit("add track", [
                "room_id": self.room_info["room_id"].intValue,
                "session_id": self.userDefaults.stringForKey("session_token")!,
                "track_id": partialTrack.playableUri.absoluteString!
            ])
        }
    }
    
    func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        var cell = tableView.cellForRowAtIndexPath(indexPath)
        
        if self.searchActive == true && self.addingTrack == false {
            cell!.contentView.backgroundColor = UIColor(red: 0.162, green: 0.173, blue: 0.188, alpha: 1.0)
        }
    }
    
    ////////////////////////////////////////////////////////////
    // UISearchBar Delegates
    
    func searchBar(searchBar: UISearchBar, textDidChange searchTerm: String) {
        
        self.tableView.tableFooterView = nil
        
        // Start search when 3+ chars are entered
        if count(searchTerm) > 0 {
            self.searchActive = true
            self.secondaryTitle.text = "SEARCH RESULTS"
            self.loadResults(searchTerm)
        }
        else if self.autoReturningFromSearch == true {
            self.didPrevHaveResults = false
            self.searchActive = false
            self.secondaryTitle.text = "NEXT"
            self.tableView!.reloadData()
        }
        else {
            self.didPrevHaveResults = false
            self.searchResultData.removeAll() // clear old data first
            self.searchActive = false
            self.secondaryTitle.text = "NEXT"
            self.tableView!.reloadData()
        }
    }
    
    func didPresentSearchController(searchController: UISearchController) {
        searchController.searchBar.showsCancelButton = false
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
    }
    
    func audioStreaming(audioStreaming: SPTAudioStreamingController!, didChangePlaybackStatus isPlaying: Bool) {
        println("*** Playing: \(isPlaying)")
    }

    // Lost internet conncetion
    func audioStreamingDidDisconnect(audioStreaming: SPTAudioStreamingController!) {
        var alert = UIAlertController(title: "Connection Error", message: "Lost connection to Spotify.", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
}
