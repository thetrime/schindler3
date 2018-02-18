//
//  ListViewController.swift
//  schindler3
//
//  Created by Matt Lilley on 17/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

import UIKit

class ListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    //MARK: Properties
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    private var items = [String]();
    private var locations: [String: [String]] = [:];
    private var sections: [String] = [];
    
    private var currentStore: Store! {
        didSet {
            navigationItem.title = currentStore.name;
            applyTableFilter();
        }
    }
    
    //MARK: Methods
    private func loadItems() {
        // FIXME: Implement this properly
    }
    
    private func loadStoreList() {
        // FIXME: Implement this
    }
    
    private func changesBetween(_ left: [String], and right: [String]) -> (deletes: IndexSet, inserts: IndexSet) {
        var deletes = IndexSet();
        var inserts = IndexSet();
        var i0 = left.makeIterator();
        var i1 = right.makeIterator();
        var s0 = i0.next();
        var s1 = i1.next();
        var index0 : Int = 0;
        var index1 : Int = 0;
        while s0 != nil || s1 != nil {
            if (s0 == nil) {
                // s1 (and the rest of i1) has been added
                inserts.insert(index1)
                index1+=1;
                s1 = i1.next();
            } else if (s1 == nil) {
                // s0 (and the rest of s0) has been deleted
                deletes.insert(index0);
                index0+=1;
                s0 = i0.next();
            }
            else if (s0! < s1!) {
                // s0 has been deleted
                deletes.insert(index0);
                index0+=1;
                s0 = i0.next();
            } else if (s0! > s1!) {
                // s1 has been added
                inserts.insert(index1);
                index1+=1;
                s1 = i1.next();
            } else if (s0! == s1!) {
                index0+=1;
                index1+=1;
                s0 = i0.next();
                s1 = i1.next();
            }
        }
        return (deletes, inserts);
    }
    
    private func applyTableFilter() {
        let filter = (searchBar.text ?? "").lowercased();
        let temporaryItem = searchBar.text ?? "";
        var newLocations: [String: [String]] = [:];
        // The list has a temporary item if the search bar is not empty and the thing in the search bar doesn't match anything in the list
        let hasTemporaryItem = filter != "" && !items.contains(where:{$0.caseInsensitiveCompare(filter) == .orderedSame})
        for item in hasTemporaryItem ? items + [temporaryItem] : items {
            if (filter != "" && !item.lowercased().contains(filter.lowercased())) {
                // The filter is not empty and this item does not match the filter. Do not include it.
                continue;
            }
            if let aisle = currentStore.getLocationOf(item) {
                // This item is in an aisle already
                if newLocations[aisle] != nil {
                    newLocations[aisle]?.append(item);
                } else {
                    newLocations[aisle] = [item];
                }
            }
            else if newLocations["Unknown"]  != nil {
                newLocations["Unknown"]?.append(item)
            } else {
                newLocations["Unknown"] = [item];
            }
        }
        for (location, itemList) in newLocations {
            newLocations[location] = itemList.sorted(by: <);
        }
        let newSections = newLocations.keys.sorted();
        
        // Now apply the table updates by comparing newLocations and locations, and newSections and sections
        //let deletedSections: [String] = sections.filter { e in !newSections.contains(e) };
        
        
        let (deletedSections, insertedSections) = changesBetween(sections, and:newSections);
        print("Sections is changing from \(sections) to \(newSections), and in the process, changing as follows:")
        print("Deleted sections: \(deletedSections)");
        print("Inserted sections: \(insertedSections)");
        for section in Set(sections).intersection(Set(newSections)) {
            let (deletedRows, insertedRows) = changesBetween(locations[section]!, and:newLocations[section]!);
            print("Section \(section) has deleted \(deletedRows) and inserted \(insertedRows)")
        }
        print("Locations: \(newLocations)")
        tableView.beginUpdates();
        for sectionTitle in Set(sections).intersection(Set(newSections)) {
            let (deletedRows, insertedRows) = changesBetween(locations[sectionTitle]!, and:newLocations[sectionTitle]!);
            tableView.deleteRows(at: deletedRows.map({IndexPath.init(row: $0, section:sections.index(of: sectionTitle)!)}), with:.automatic);
            tableView.insertRows(at: insertedRows.map({IndexPath.init(row: $0, section:newSections.index(of: sectionTitle)!)}), with:.automatic);
            // FIXME: If we have a temporary item, do not delete and insert it, instead update the row.
        }
        tableView.deleteSections(deletedSections, with:.automatic);
        tableView.insertSections(insertedSections, with:.automatic);
        locations = newLocations;
        sections = newSections;
        print("Committing changes...");
        tableView.endUpdates();
        //tableView.reloadData();
    }
    
    private func determineStore() {
        // FIXME: Implement this properly
        currentStore = Store(name:"Home");
        items.append("cat");
        items.append("banjo");
        items.append("cabbage");
        items.append("potato");
        
        currentStore?.setItemLocation("cat", to: "Lounge");
        currentStore?.setItemLocation("potato", to:"Kitchen");
        currentStore?.setItemLocation("banjo", to: "Lounge");
        applyTableFilter();
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView();
        loadItems();
        loadStoreList();
        determineStore();
        searchBar.delegate = self;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: UITableViewDelegate
    func numberOfSections(in tableView: UITableView) -> Int {
        return locations.keys.count;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("Number of rows in section \(section): \(locations[sections[section]]!.count)");
        return locations[sections[section]]!.count;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "ListItemTableViewCell";
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ListItemTableViewCell  else {
            fatalError("The dequeued cell is not an instance of ListItemTableViewCell.")
        }
        let section = sections[indexPath.section];
        guard let items = locations[section] else {
            fatalError("Request for non-existent section \(section)?");
        }
        print("Request for item at section \(indexPath.section), row \(indexPath.row). This section contains \(items)");
        cell.label.text = items[indexPath.row];
        return cell;
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section];
    }
    
    // MARK: UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyTableFilter();
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
