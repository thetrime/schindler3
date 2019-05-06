//
//  DataManager.swift
//  schindler3
//
//  Created by Matt Lilley on 25/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

// Ideally this should have a handle to the various view controllers so that when we update something they might care about
// we can trigger an update in their table(s).

import Foundation
import CoreLocation;
import SQLite3;

class DataManager {
    
    private var stores: [String: (Double,Double)] = [:];
    private var items: [String] = [];
    private var currentList: [String] = [];
    private var db = SQLiteDatabase(file:"schindler3.db");
    private var net: NetworkManager!;
    var delegate: ListViewController?;
    
    var userId: String = "matt";
    var password: String = "notverysecretatall";
    
    var currentStore: Store! {
        didSet {
            print("setting navigation title");
            delegate!.movedStore(to:currentStore.name);
        }
    }
    
    func determineStore(near location: (Double, Double)) {
        let newStore = findStoreClosestTo(location);
        print("moving to \(newStore) from \(currentStore.name)")
        if (newStore != currentStore.name) {
            clearDeferredItems()
            print("Deferrals cleared")
            currentStore = loadStoreNamed(newStore);
        }
    }
    
    func getAislesOfCurrentStore() -> [String] {
        var aisles : [String] = [];
        for row in db.select(from:"store_contents", values:["location"], where:["store_name": currentStore.name], orderBy: ["location": "asc"]) {
            if let i = row["location"] as? String {
                if !aisles.contains(i) {
                    aisles.append(i);
                }
            }
        }
        return aisles;
    }
    
    
    init() {
        prepareSchema();
        loadStoreLocations();
        loadItems();
        loadCurrentList();
        net = NetworkManager(withDataManager: self);
    }
    
    func setDelegate(_ d: ListViewController) {
        delegate = d;
    }
    
    func configure(_ userId: String, _ password: String) -> Bool {
        self.userId = userId
        self.password = password
    
        return true
    }
    
    private func prepareSchema() {

        db.createTable(named: "item", withColumns: ["item": "text"], andUniqueConstraints: [["item"]]);
        db.createTable(named: "current_list", withColumns: ["item": "TEXT"], andUniqueConstraints: [["item"]]);
        db.createTable(named: "store", withColumns: ["store_name": "TEXT",
                                                      "latitude": "FLOAT",
                                                      "longitude": "FLOAT"], andUniqueConstraints: [["store_name"], ["latitude", "longitude"]]);
        db.createTable(named: "store_contents", withColumns: ["store_name": "TEXT",
                                                              "item": "TEXT",
                                                              "location": "TEXT"], andUniqueConstraints: [["store_name", "item", "location"]]);
        db.createTable(named: "outgoing_messages", withColumns: ["local_id": "INTEGER PRIMARY KEY",
                                                                 "message": "TEXT"]);
        db.createTable(named: "sync_state", withColumns: ["timestamp": "BIGINTEGER"]);
        db.createTable(named: "messages", withColumns: ["message_id": "INTEGER PRIMARY KEY",
                                                        "message": "TEXT"]);
        db.createTable(named: "deferred_items", withColumns: ["item": "TEXT"], andUniqueConstraints: [["item"]]);
        syncPoint()
    }
    
    func syncPoint() -> Int64 {
        for row in db.select(from:"sync_state", values:["timestamp"]) {
            if let i = row["timestamp"] as? Int64 {
                return i;
            }
        }
        print("WARNING: No sync state!")
        db.insert(to:"sync_state", values:["timestamp": 0])
        return 0;
    }
    
    func setSync(to timestamp:Int64) {
        db.update("sync_state",
                  set:["timestamp": timestamp]);
        print("Sync point is now \(timestamp)")
    }
    
    private func loadItems() {
        items = [];
        for row in db.select(from:"item", values:["item"]) {
            if let i = row["item"] as?  String {
                items.append(i);
            }
        }
    }
    
    private func loadCurrentList() {
        currentList = [];
        for row in db.select(from: "current_list", values:["item"]) {
            if let i = row["item"] as?  String {
                currentList.append(i);
            }
        }
        print("Current list is now \(currentList)")
    }
    
    private func loadStoreLocations () {
        stores = [:];
        for row in db.select(from: "store", values:["store_name", "latitude", "longitude"]) {
            if let name = row["store_name"] as? String,
                let latitude = row["latitude"] as? Double,
                let longitude = row["longitude"] as? Double {
                stores[name] = (latitude, longitude);
            }
        }
    }
    
    func createStoreNamed(_ name: String, atLocation location:(Double, Double), _ unsolicited: Bool = false) {
        if (stores[name] != nil) {
            // The store already exists. Move it instead (if needed)
            setLocationOf(store: name, to: location);
        } else {
            db.insert(to: "store", values:["store_name": name,
                                           "latitude": location.0,
                                           "longitude": location.1]);
        }
        stores[name] = location;
        if (!unsolicited) {
            net.queueMessage(["opcode":"store_located_at", "store_id": name, "latitude": String(location.0), "longitude": String(location.1), "timestamp":getCurrentMillis()])
        }
    }
    
    func addItemToList(named item:String, _ unsolicited: Bool = false) {
        db.insert(to:"current_list", values:["item": item]);
        if (!currentList.contains(item)) {
            print("list \(currentList) does not contain \(item)")
            currentList.append(item);
        }
        if (!items.contains(item)) {
            createItem(named:item, unsolicited);
        }
        if (!unsolicited) {
            net.queueMessage(["opcode":"item_added_to_list", "item_id":item, "timestamp":getCurrentMillis()])
        }
    }

    func createItem(named item: String, _ unsolicited: Bool = false) {
        db.insert(to:"item", values:["item":item]);
        if (!items.contains(item)) {
            items.append(item);
        }
        if (!unsolicited) {
            net.queueMessage(["opcode":"item_exists", "item_id":item, "timestamp":getCurrentMillis()])
        }
    }
    
    private func getCurrentMillis()->Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    func indicateConnected() {
        delegate!.indicateConnected()
    }
    
    func indicateDisconnected() {
        delegate!.indicateDisconnected()
    }
    
    func clearDeferredItems() {
        db.delete(from:"deferred_items")
    }
    
    func deferItem(item: String) {
        db.insert(to:"deferred_items", values: ["item":item]);
        // No need to tell the server about this
    }
    
    func deferredItems() -> [String] {
        var deferredItems: [String] = []
        for row in db.select(from:"deferred_items", values:["item"]) {
            deferredItems.append(row["item"] as! String)
        }
        return deferredItems
        
    }
    
    func move(item: String, toUnknownLocationAtStore store: String, _ unsolicited: Bool = false) {
        db.delete(from:"store_contents", where:["store_name":store,
                                                "item":item]);
        if (!unsolicited) {
            net.queueMessage(["opcode": "item_removed_from_aisle", "item_id": item, "store_id": store, "timestamp":getCurrentMillis()])
        }
        if (store == currentStore.name) {
            currentStore.moveToUnknownLocation(item: item)
        }
    }
    
    func setLocationOf(item: String, atStore store: String, toLocation location: String, _ unsolicited: Bool = false) {
        // TBD: Do this in a single transaction. It isnt super-important, though, so long as we only send the one message to the backend
        db.delete(from:"store_contents", where:["store_name":store,
                                                "item":item]);
        db.insert(to:"store_contents", values:["store_name":store,
                                               "item": item,
                                               "location": location]);
        print("Item \(item) moved to \(location) at store \(store)")
        if (!unsolicited) {
            net.queueMessage(["opcode":"item_located_in_aisle", "item_id": item, "store_id": store, "aisle_id": location, "timestamp":getCurrentMillis()])
        }
        if (store == currentStore.name) {
            currentStore.setItemLocation(item, to: location);
        }
    }
    
    func deleteListItem(named item:String, _ unsolicited: Bool = false) {
        db.delete(from:"current_list", where:["item": item]);
        currentList = currentList.filter( { $0 != item } );
        if (!unsolicited) {
            net.queueMessage(["opcode":"item_deleted_from_list", "item_id":item, "timestamp":getCurrentMillis()]);
        }
    }
    
    func setLocationOf(store name:String, to location:(Double, Double), _ unsolicited: Bool = false) {
        if stores[name] == nil {
            createStoreNamed(name, atLocation:location, unsolicited);
        } else {
            print("Moving \(name) to \(location)")
            db.update("store",
                      set:["latitude":location.0,
                           "longitude":location.1],
                      where:["store_name":name]);
            stores[name] = location;
        }
        if (!unsolicited) {
            net.queueMessage(["opcode":"store_located_at", "store_id": name, "latitude": String(location.0), "longitude": String(location.1), "timestamp":getCurrentMillis()])
        }

    }
    
    func handleUnsolicitedMessage(withOpcode opcode: String, data: [String:Any]) {
        DispatchQueue.main.async {
            self.delegate!.updateTable(after:) {
                self.handleUnsolicitedMessageOnMainThread(withOpcode: opcode, data:data)
            }
        }
    }
    
    func resyncFromScratch() {
        db.softNuke()
        net.queueMessage(["opcode":"sync", "timestamp":syncPoint()])
    }
    
    private func handleUnsolicitedMessageOnMainThread(withOpcode opcode: String, data: [String:Any]) {
        print("Handling unsolicited message \(opcode) with data \(data)")
        switch (opcode) {
            case "sync_response":
                for submessage in data["messages"] as! [[String:Any]] {
                    handleUnsolicitedMessageOnMainThread(withOpcode: submessage["opcode"] as! String, data: submessage)
                }
                setSync(to: data["timestamp"] as! Int64)
            case "item_exists":
                let item = data["item_id"] as! String
                createItem(named: item, true)
            case "store_exists":
                let store_id = data["store_id"] as! String
                createStoreNamed(store_id, atLocation: (0,0), true)
            case "store_located_at":
                let store_id = data["store_id"] as! String
                let (latitude, longitude) = (Double(data["latitude"] as! String)!, Double(data["longitude"] as! String)!)
                setLocationOf(store: store_id, to: (latitude, longitude), true)
                // This is actually not implemented. You cannot have an aisle in a store with nothing in it
                // case "aisle_exists_in_store":
            case "item_deleted_from_list":
                let item_id = data["item_id"] as! String
                deleteListItem(named: item_id, true)
            case "item_located_in_aisle":
                let (item_id, store_id, aisle_id) = (data["item_id"] as! String, data["store_id"] as! String, data["aisle_id"] as! String)
                setLocationOf(item: item_id, atStore: store_id, toLocation: aisle_id, true)
            case "item_removed_from_aisle":
                let (item_id, store_id) = (data["item_id"] as! String, data["store_id"] as! String)
                move(item: item_id, toUnknownLocationAtStore: store_id, true);
            case "item_added_to_list":
                let item = data["item_id"] as! String
                addItemToList(named: item, true);
            case "login_denied":
                let defaults = UserDefaults.standard
                defaults.set(nil, forKey: "username")
                defaults.set(nil, forKey: "password")
                delegate!.login()
        case "nuke":
                db.nuke()
            default:
                print("Unhandled unsolicited message \(opcode)")
            }
    }
    
    
    func itemExists(_ item: String) -> Bool {
        return items.contains(where:{$0.caseInsensitiveCompare(item) == .orderedSame});
    }
    
    func getStoreList() -> [String] {
        return Array(stores.keys);
    }

    func getItems() -> [String] {
        return items;
    }
    
    func getCurrentList() -> [String] {
        //print("Current list::: \(currentList)")
        return currentList;
    }

    func findStoreClosestTo(_ location: (Double, Double)) -> String {
        var bestMatch = ("Home", Double.infinity);
        let c = CLLocation(latitude: location.0, longitude: location.1);
        for (storeName, location) in stores {
            let distanceInMeters =  CLLocation(latitude:location.0, longitude:location.1).distance(from:c);
            print("Distance to \(storeName) is \(distanceInMeters)");
            if (distanceInMeters < bestMatch.1) {
                bestMatch.1 = distanceInMeters;
                bestMatch.0 = storeName;
            }
        }
        return bestMatch.0;
    }
    
    func updateGlobalState(to value: Int) {
        if (getGlobalState() == 0) {
            db.insert(to:"global_state", values:["global_id": value])
        } else {
            db.update("global_state", set:["global_id": value]);
        }
    }
    
    func getGlobalState() -> Int {
        for row in db.select(from:"global_state", values:["global_id"]) {
            if let global_id = row["global_id"] as? Int {
                return global_id;
            }
        }
        return 0;
    }
    
    func loadStoreNamed(_ name: String) -> Store {
        let s = Store(name:name, dataSource:self);
        for row in db.select(from: "store_contents", values:["location", "item"], where:["store_name":name]) {
            print("Loading \(row)")
            if let location = row["location"] as? String,
                let item = row["item"] as? String {
                print("Location of \(item) is set to \(location) at \(name)")
                s.setItemLocation(item, to:location);
            }
        }
        print("Loaded store \(name) from disk");
        return s;
    }
    
    func storeMessage(_ message: String) -> Int64 {
        return db.insert(to: "messages", values:["message": message]);
    }
    
    func deleteMessage(_ id: Int64) {
        db.delete(from: "messages", where: ["message_id":id])
    }
    
    func missedMessages() -> [[String:Any]] {
        return db.select(from: "messages", values:["message", "message_id"], orderBy:["message_id":"asc"])
    }
}
