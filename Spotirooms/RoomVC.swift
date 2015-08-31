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

class RoomVC: UIViewController, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate, UITableViewDataSource, UITableViewDelegate, UISearchControllerDelegate, UISearchBarDelegate {
    
    @IBOutlet weak var loadingCoverView: UIView!
    var myActivityIndicatorView: DTIActivityIndicatorView!
    
    var searchController : UISearchController!
    var searchActive: Bool = false
    var didPrevHaveResults: Bool = false
    var storedAddButton: UIBarButtonItem!
    
    @IBOutlet weak var tableView: UITableView!
    var filteredData = [[String]]()
    var loadingMoreResults: Bool = false
    var shown_listPage: SPTListPage!
    
    var socketConnected: Bool! = false
    var playerConnected: Bool! = false
    
    var room_info: JSON!
    let socket = SocketIOClient(socketURL: Constants.socketURL, opts: [
        "nsp": "/test",
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
        
        self.searchController.searchBar.placeholder = "Search for track"
        
        self.searchController.searchBar.sizeToFit()
        
        // Sets this view controller as presenting view controller for the search interface
        definesPresentationContext = true
        
        // Handling data and setting up connections
        let room_dict = self.room_info.dictionaryValue
        self.title = room_info["name"].stringValue
        
        self.addHandlers()
        self.socket.connect()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Show activity indicator
        self.myActivityIndicatorView = DTIActivityIndicatorView(frame: CGRect(x:self.view.center.x-40, y:self.view.center.y-80, width:80.0, height:80.0))
        self.loadingCoverView.addSubview(self.myActivityIndicatorView)
        self.myActivityIndicatorView.indicatorColor = UIColor.whiteColor()
        self.myActivityIndicatorView.indicatorStyle = "spotify"
        self.myActivityIndicatorView.startActivity()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.handleNewSession()
        var timer = NSTimer.scheduledTimerWithTimeInterval(30.0, target: self, selector: "checkConnect", userInfo: nil, repeats: false)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.socket.close(fast: false)
        println("*** Socket Disconnected ***")
        
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
    
    func checkConnect() {
        if self.socketConnected == false || self.playerConnected == false {
            println("*** Timeout error ***")
            self.myActivityIndicatorView.stopActivity(true)
            var alert = UIAlertController(title: "Connection Error", message: "Connection timed out.", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
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
    
    func hideLoadingView() {
        if self.socketConnected == true && self.playerConnected == true {
            self.myActivityIndicatorView.stopActivity(true)
            self.navigationItem.rightBarButtonItem?.enabled = true
            UIView.animateWithDuration(0.5, animations: {
                self.loadingCoverView.alpha = 0
                }, completion: { _ in
                    self.loadingCoverView.hidden = true
            })
        }
    }
    
    func addHandlers() {
        self.socket.on("my response") {data, ack in
            var dict = data![0] as! NSDictionary
            var response: AnyObject! = dict["data"]
            println("Received: \(response)")
        }
        
        self.socket.on("connect") {data, ack in
            println("*** Socket Connected ***")
            self.socketConnected = true
            self.hideLoadingView()
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
                var alert = UIAlertController(title: "Connection Error", message: "Could not connect to Spotify.", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in self.handleAlert(alert, action: action)}))
                self.presentViewController(alert, animated: true, completion: nil)
                self.navigationController?.popViewControllerAnimated(true)
                return
            }
            
            println("*** Player Connected ***")
            self.playerConnected = true
            self.hideLoadingView()
            
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
            
        })
    }
    
    @IBAction func pressedAddButton() {
        self.navigationItem.hidesBackButton = true
        self.navigationItem.rightBarButtonItem = nil
        self.navigationItem.titleView = self.searchController.searchBar
        var cancelButton = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.Plain, target: self, action: "pressedCancelButton")
        self.navigationItem.rightBarButtonItem = cancelButton
        self.tableView.hidden = false
        
        self.searchController.searchBar.becomeFirstResponder()
    }
    
    func pressedCancelButton() {
        self.searchController.searchBar.text = nil
        self.searchBar(self.searchController.searchBar, textDidChange: "")
        self.tableView.hidden = true
        self.navigationItem.hidesBackButton = false
        self.navigationItem.rightBarButtonItem = self.storedAddButton
        self.navigationItem.titleView = nil
    }
    
     
    func pressedButton() {
        // self.socket.emit("my event", ["data": "worked again baby!"])
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
                        self.filteredData.append(["No results", ""])
                    }
                    
                }
                else {
                    self.shown_listPage = listPage
                    
                    // Remove old data here so that if new search is nil we still have old results
                    self.didPrevHaveResults = true
                    self.filteredData.removeAll()
                    for item in listPage.items {
                        let partialTrack = item as! SPTPartialTrack
                        let partialArtist = partialTrack.artists[0] as! SPTPartialArtist
                        
                        self.filteredData.append([partialTrack.name, partialArtist.name])
                    }
                    
                    if listPage.hasNextPage == false {
                        self.filteredData.append(["", "- END OF RESULTS -"])
                    }

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
                
                for item in listPage.items {
                    let partialTrack = item as! SPTPartialTrack
                    let partialArtist = partialTrack.artists[0] as! SPTPartialArtist
                    
                    self.filteredData.append([partialTrack.name, partialArtist.name])
                }
                
                if listPage.hasNextPage == false {
                    self.filteredData.append(["", "- END OF RESULTS -"])
                }
                
                activityIndicator.stopAnimating()
                self.tableView.tableFooterView = nil
                self.tableView!.reloadData()
                self.loadingMoreResults = false
            })
        }
    }
    
    ////////////////////////////////////////////////////////////
    // UITableViewDataSource methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = searchActive ? filteredData.count : 1
        return count
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 38
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("cell") as? UITableViewCell
        
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "cell")
        }
        
        if searchActive {
            let result = self.filteredData[indexPath.row]
            cell!.textLabel?.text = result[0]
            cell!.detailTextLabel?.text = result[1]
            
            if self.shown_listPage != nil {
                if indexPath.row == self.filteredData.count-1 && self.shown_listPage.hasNextPage == true {
                    self.loadMoreResults()
                }
            }
        }
        else {
            cell!.textLabel?.text = ""
            cell!.detailTextLabel?.text = "Start typing to begin searching..."
        }
        
        cell!.selectionStyle = UITableViewCellSelectionStyle.Default
        
        return cell!
    }
    
    ////////////////////////////////////////////////////////////
    // UITableViewDelegate methods
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var cell = tableView.cellForRowAtIndexPath(indexPath)
        
        
        // tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    /*func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        var cell = tableView.cellForRowAtIndexPath(indexPath)
        
        //cell!.textLabel?.textColor = UIColor.groupTableViewBackgroundColor()
        //cell!.detailTextLabel?.textColor = UIColor.lightGrayColor()
    }*/
    
    ////////////////////////////////////////////////////////////
    // UISearchBar Delegates
    
    func searchBar(searchBar: UISearchBar, textDidChange searchTerm: String) {
        
        // Start search when 3+ chars are entered
        if count(searchTerm) > 2 {
            self.searchActive = true
            self.loadResults(searchTerm)
        }
        else if count(searchTerm) > 0 {
            self.didPrevHaveResults = false
            self.filteredData.removeAll() // clear old data first
            // Pretend no results while less than 3 chars entered
            self.searchActive = true
            self.filteredData.append(["No results", ""])
            
            self.tableView!.reloadData()
        }
        else {
            self.didPrevHaveResults = false
            self.filteredData.removeAll() // clear old data first
            self.searchActive = false
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
    
    func audioStreaming(audioStreaming: SPTAudioStreamingController!, didChangeToTrack trackMetadata: [NSObject : AnyObject]!) {
        let trackname: AnyObject? = trackMetadata["SPTAudioStreamingMetadataTrackName"]
        println("*** Track changed to: \(trackname!)")
    }
    
    func audioStreaming(audioStreaming: SPTAudioStreamingController!, didChangePlaybackStatus isPlaying: Bool) {
        println("*** Playing: \(isPlaying)")
    }


}
