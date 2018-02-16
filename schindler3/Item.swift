//
//  Item.swift
//  schindler3
//
//  Created by Matt Lilley on 17/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

import Foundation

class Item : Hashable, CustomStringConvertible {
    let name: String;
    
    init(name: String) {
        self.name = name;
    }
    
    //MARK: CustomStringConvertible
    var description: String {
        return "Item: \(self.name)";
    }
    
    //MARK: Hashable
    var hashValue: Int {
        get {
            return name.hashValue;
        }
    }
    
    static func == (lhs: Item, rhs: Item) -> Bool {
        return lhs.name == rhs.name;
    }
    
    static func < (lhs: Item, rhs: Item) -> Bool {
        return lhs.name < rhs.name;
    }
}
