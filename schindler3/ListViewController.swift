//
//  ListViewController.swift
//  schindler3
//
//  Created by Matt Lilley on 17/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

import UIKit

class ListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    //MARK: Properties
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    private var items = [Item]();
    private var itemLocations: [String: [Item]] = [:];
    private var sections: [String] = [];
    
    private var currentStore: Store! {
        didSet {
            determineItemLocations();
        }
    }
    
    //MARK: Methods
    private func loadItems() {
        // FIXME: Implement this properly
    }
    
    private func loadStoreList() {
        // FIXME: Implement this
    }
    
    private func determineItemLocations() {
        var locations: [String: [Item]] = [:];
        for item in items {
            if let aisle = currentStore.getLocationOf(item) {
                if locations[aisle] != nil {
                    locations[aisle]?.append(item);
                } else {
                    locations[aisle] = [item];
                }
            }
            else if locations["Unknown"]  != nil {
                locations["Unknown"]?.append(item)
            } else {
                locations["Unknown"] = [item];
            }
        }
        for (location, itemList) in locations {
            locations[location] = itemList.sorted(by: <);
        }
        itemLocations = locations;
        print("itemLocations: \(itemLocations)");
        sections = itemLocations.keys.sorted();
    }
    
    private func determineStore() {
        // FIXME: Implement this properly
        currentStore = Store(name:"Home");
        let cat = Item(name:"cat");
        let potato = Item(name:"potato")
        let banjo = Item(name:"banjo")
        let cabbage = Item(name:"cabbage");
        items.append(cat);
        items.append(banjo);
        items.append(cabbage);
        items.append(potato);
        
        currentStore?.setItemLocation(cat, to: "Lounge");
        currentStore?.setItemLocation(potato, to:"Kitchen");
        currentStore?.setItemLocation(banjo, to: "Lounge");
        determineItemLocations();
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView();
        loadItems();
        loadStoreList();
        determineStore();
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: UITableViewDelegate
    func numberOfSections(in tableView: UITableView) -> Int {
        print("Number of sections: \(itemLocations)");
        return itemLocations.keys.count;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("Number of rows in section \(section): \(itemLocations[sections[section]]!.count)");
        return itemLocations[sections[section]]!.count;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "ListItemTableViewCell";
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ListItemTableViewCell  else {
            fatalError("The dequeued cell is not an instance of ListItemTableViewCell.")
        }
        let section = sections[indexPath.section];
        guard let items = itemLocations[section] else {
            fatalError("Request for non-existent section \(section)?");
        }
        print("Request for item at section \(indexPath.section), row \(indexPath.row). This section contains \(items)");
        cell.label.text = items[indexPath.row].name;
        return cell;
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section];
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
