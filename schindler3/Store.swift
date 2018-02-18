//
//  Store.swift
//  schindler3
//
//  Created by Matt Lilley on 17/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

import Foundation

class Store {
    var name: String;
    var aisles: [String: [String]];
    private var locations: [String:String];
    init(name: String) {
        self.name = name;
        aisles = [:];
        locations = [:];
    }
    
    //MARK: Methods
    func setItemLocation(_ item: String, to aisle: String) {
        if var items = aisles[aisle] {
            items.append(item);
        } else {
            aisles[aisle] = [item];
        }
        locations[item] = aisle;
    }
    
    func getLocationOf(_ item: String) -> String? {
        return locations[item];
    }
}
