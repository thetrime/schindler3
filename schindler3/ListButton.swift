//
//  ListButton.swift
//  schindler3
//
//  Created by Matt Lilley on 20/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

import UIKit

class ListButton: UIButton {
    var item: String?;
    enum ButtonType {
        case add(String);
        case get(String);
        case set(String);
    }
    var row: Int {
        get {
            var v: UIView! = self;
            repeat {
                v = v.superview!
            } while !(v is UITableViewCell)
            let cell = v as! UITableViewCell
            let table: UITableView = cell.superview as! UITableView;
            let path = table.indexPath(for: cell)!;
            return path.row;
        }
    }
    var section: Int {
        get {
            var v: UIView! = self;
            repeat {
                v = v.superview!
            } while !(v is UITableViewCell)
            let cell = v as! UITableViewCell
            let table: UITableView = cell.superview as! UITableView;
            let path = table.indexPath(for: cell)!;
            return path.section;
        }
    }
    
    var type: ButtonType = .add("Unknown") {
        didSet {
            switch (type) {
            case .add(_):
                setTitle("Add", for:.normal);
            case .get(_):
                setTitle("Got it", for:.normal);
            case .set(_):
                setTitle("Here", for:.normal);
            }
        }
    }
}
