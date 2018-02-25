//
//  DataManager.swift
//  schindler3
//
//  Created by Matt Lilley on 25/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

import Foundation
import CoreLocation;
import SQLite3;

class DataManager {
    
    private var stores: [String: (Double,Double)] = [:];
    private var items: [String] = [];
    private var currentList: [String] = [];
    private var db = SQLiteDatabase(file:"schindler3.db");
    init() {
        prepareSchema();
        loadStoreLocations();
        loadItems();
        loadCurrentList();
    }
    
    private func prepareSchema() {
        db.createTable(named: "item", withColumns: ["item": "text"]);
        db.createTable(named: "current_list", withColumns: ["item": "TEXT"]);
        db.createTable(named: "store", withColumns: ["store_name": "TEXT",
                                                      "latitude": "FLOAT",
                                                      "longitude": "FLOAT"]);
        db.createTable(named: "store_contents", withColumns: ["store_name": "TEXT",
                                                              "item": "TEXT",
                                                              "location": "TEXT"]);
        /* Test data */
        /*
        createItem(named: "Cat");
        createItem(named: "Banana");
        createItem(named: "Cabbage");
        createItem(named: "Potato");
        createItem(named: "Leek");
        createItem(named: "Steamed monkfish liver");
        createItem(named: "Expired spicy fish eggs");
        createItem(named: "Poop");
        addItemToList(named: "Cat");
        addItemToList(named: "Potato");
        addItemToList(named: "Banana");
        createStoreNamed("Tesco", atLocation: (10,0));
        createStoreNamed("Home", atLocation: (0,10));
        createStoreNamed("Morrisons", atLocation: (20,0));
        setLocationOf(item: "Cat", atStore: "Home", toLocation: "Lounge")
        setLocationOf(item: "Potato", atStore: "Home", toLocation: "Kitchen")
        setLocationOf(item: "Leek", atStore: "Home", toLocation: "Lounge")
        setLocationOf(item: "Poop", atStore: "Home", toLocation: "Toilet")
    */
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
                print("Here: " + i)
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
    
    func createStoreNamed(_ name: String, atLocation location:(Double, Double)) {
        if (stores[name] != nil) {
            // The store already exists. Move it instead (if needed)
            setLocationOf(store: name, to: location);
        } else {
            db.insert(to: "store", values:["store_name": name,
                                           "latitude": location.0,
                                           "longitude": location.1]);
        }
        stores[name] = location;
    }
    
    func addItemToList(named item:String) {
        db.insert(to:"current_list", values:["item": item]);
        currentList.append(item);
        if (!items.contains(item)) {
            createItem(named:item);
        }
    }
    
    func move(item: String, toUnknownLocationAtStore store: String) {
        db.delete(from:"store_contents", where:["store_name":store,
                                                "item":item]);
    }
    
    func setLocationOf(item: String, atStore store: String, toLocation location: String) {
        // TBD: Do this in a single transaction. It isnt super-important, though, so long as we only send the one message to the backend
        db.delete(from:"store_contents", where:["store_name":store,
                                                "item":item]);
        db.insert(to:"store_contents", values:["store_name":store,
                                               "item": item,
                                               "location": location]);
    }
    
    func deleteListItem(named item:String) {
        db.delete(from:"current_list", where:["item": item]);
        currentList = currentList.filter( { $0 != item } );
    }
    
    func setLocationOf(store name:String, to location:(Double, Double)) {
        if stores[name] == nil {
            createStoreNamed(name, atLocation:location);
        } else {
            print("Moving \(name) to \(location)")
            db.update("store",
                      set:["latitude":location.0,
                           "longitude":location.1],
                      where:["store_name":name]);
            stores[name] = location;
        }
    }
    
    func createItem(named item: String) {
        db.insert(to:"item", values:["item":item]);
        items.append(item);
    }
    
    func itemExists(_ item: String) -> Bool {
        return items.contains(where:{$0.caseInsensitiveCompare(item) == .orderedSame});
    }
    
    func getStoreList() -> [String] {
        print("Foo \(stores)")
        return Array(stores.keys);
    }

    func getItems() -> [String] {
        return items;
    }
    
    func getCurrentList() -> [String] {
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
}
