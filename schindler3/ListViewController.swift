//
//  ListViewController.swift
//  schindler3
//
//  Created by Matt Lilley on 17/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//
// TODO List:
//    Implement the add/got it buttons
//    Implement the store/aisle configurations
//    Add GPS info
//    Save the state to disk after modifications
//    Queue the messages to be sent
//    Send and process messages when network is online

import UIKit

class ListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    //MARK: Properties
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    private var items = [String]();
    private var currentList = [String]();
    private var locations: [String: [String]] = [:];
    private var sections: [String] = [];
    private var temporaryItemRow: Int?;
    private var searchFilter: String = "";
    
    private var currentStore: Store! {
        didSet {
            navigationItem.title = currentStore.name;
            updateTable(after:) {}
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
            } else if (s0! < s1!) {
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
    
    private func updateTableView() {
        let temporaryItem = searchFilter;
        let filter = searchFilter.lowercased();
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
        if (hasTemporaryItem) {
            // FIXME: Nope. The new item could be in any section!
            temporaryItemRow = newLocations["Unknown"]?.index(of:temporaryItem);
        } else {
            temporaryItemRow = nil;
        }
        
        // Table update is hard to get your head around. The general idea is:
        // * First all the row deletes are processed
        // * Next, all the section deletes are processed
        // * Then, the row inserts are processed
        // * Finally, if any sections have been added they are loaded
        
        let (deletedSections, insertedSections) = changesBetween(sections, and:newSections);
        print("Updated Locations: \(newLocations)")
        print("Sections is changing from \(sections) to \(newSections), and in the process, changing as follows:")
        print("   * Deleted sections: \(deletedSections)");
        print("   * Inserted sections: \(insertedSections)");
        
        for sectionTitle in Set(sections).intersection(Set(newSections)) {
            let (deletedRows, insertedRows) = changesBetween(locations[sectionTitle]!, and:newLocations[sectionTitle]!);
            let sectionIndex = sections.index(of: sectionTitle)!;
            let newSectionIndex = newSections.index(of: sectionTitle)!
            let modifiedRows = Set(deletedRows).intersection(Set(insertedRows));
            let onlyDeletedRows = Set(deletedRows).subtracting(modifiedRows);
            let onlyInsertedRows = Set(insertedRows).subtracting(modifiedRows);
            print("   * Section \(sectionTitle) (was index \(sectionIndex) but is now \(newSectionIndex))");
            print("      * Deleted \(onlyDeletedRows) from section \(sectionIndex)");
            print("      * Inserted \(onlyInsertedRows) to section \(newSectionIndex)");
            print("      * Updated \(modifiedRows) on section \(sectionIndex)");
            tableView.deleteRows(at: onlyDeletedRows.map({IndexPath.init(row: $0, section:sectionIndex)}), with:.automatic);
            tableView.insertRows(at: onlyInsertedRows.map({IndexPath.init(row: $0, section:newSectionIndex)}), with:.automatic);
            tableView.reloadRows(at: modifiedRows.map({IndexPath.init(row: $0, section:sectionIndex)}), with:.automatic);
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
        updateTable(after:) {
            currentStore = Store(name:"Home");
            items.append("cat");
            items.append("banjo");
            items.append("cabbage");
            items.append("potato");
            
            currentStore?.setItemLocation("cat", to: "Lounge");
            currentStore?.setItemLocation("potato", to:"Kitchen");
            currentStore?.setItemLocation("banjo", to: "Lounge");
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
       // tableView.tableFooterView = UIView();
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
        if (section == "Unknown" && indexPath.row == temporaryItemRow) {
            cell.button.type = .add(items[indexPath.row])
        } else {
            cell.button.type = .get(items[indexPath.row])
        }
        cell.button.addTarget(self, action:#selector(ListViewController.buttonPressed(button:)), for: .touchUpInside);
        return cell;
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section];
    }
    
    private func updateTable(after: () -> Void) {
        tableView.beginUpdates()
        after();
        updateTableView();
    }
    
    // MARK: Button handler
    @objc func buttonPressed(button: ListButton) {
        updateTable(after:) {
            if case .add(let item) = button.type {
                items.append(item);
                searchBar.text = "";
                //tableView.reloadRows(at: [IndexPath(row: ?, section: ?)]);
            } else if case .get(let item) = button.type {
                items = items.filter( { $0 != item } );
            }
        }
    }
    
    // MARK: UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateTable(after:) {
            searchFilter = searchText;
        }
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
