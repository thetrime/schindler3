//
//  ListViewController.swift
//  schindler3
//
//  Created by Matt Lilley on 17/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//
// TODO List:
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
    @IBOutlet weak var setLocationButton: UIBarButtonItem!
    
    private var items = [String]();
    private var currentList = [String]();
    private var locations: [String: [String]] = [:];
    private var sections: [String] = [];
    private var temporaryItemRow: Int?;
    private var searchFilter: String = "";
    private var storeNames: [String] = [];
    
    private var currentStore: Store! {
        didSet {
            print("setting navigation title");
            navigationItem.title = currentStore.name;
            updateTable(after:) {}
        }
    }
    
    //MARK: Methods
    private func loadStoreList() {
        // FIXME: load these from a file
        createStoreNamed("Home");
        createStoreNamed("Tesco");
        createStoreNamed("Morrisons");
    }

    
    private func updateTableView() {
        let temporaryItem = searchFilter;
        let filter = searchFilter.lowercased();
        var newLocations: [String: [String]] = [:];
        // The list has a temporary item if the search bar is not empty and the thing in the search bar doesn't match anything in the list
        let hasTemporaryItem = filter != "" && !items.contains(where:{$0.caseInsensitiveCompare(filter) == .orderedSame})
        for item in hasTemporaryItem ? items + [temporaryItem] : items {
            if (filter != "" && !item.lowercased().contains(filter)) {
                // The filter is not empty and this item does not match the filter. Do not include it.
                continue;
            }
            if (filter == "" && !currentList.contains(item)) {
                // The filter IS empty so we only want to display items actually on the current list
                print("Breaking here for \(item)")
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
    
    private func loadItems() {
        // FIXME: Load these from a file
        items.append("cat");
        items.append("banana");
        items.append("cabbage");
        items.append("potato");
        items.append("leek");
        items.append("steamed monkfish liver");
        items.append("expired spicy fish eggs");
        items.append("Poop");
    }
    
    private func loadList() {
        // FIXME: Load these from a file
        currentList.append("cat");
        currentList.append("potato");
        currentList.append("banana");

    }
    
    private func determineStore() {
        // FIXME: Implement this properly
        updateTable(after:) {
            currentStore = loadStoreNamed("Home");
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
       // tableView.tableFooterView = UIView();
        loadItems();
        loadList();
        loadStoreList();
        determineStore();
        searchBar.delegate = self;
        setLocationButton.target = self;
        setLocationButton.action = #selector(ListViewController.setLocationButtonPressed(button:));
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath){
        searchBar.resignFirstResponder();
    }
    
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
        if (currentList.contains(items[indexPath.row])) {
            cell.button.type = .get(items[indexPath.row]);
        } else {
            cell.button.type = .add(items[indexPath.row]);
        }
        cell.button.row = indexPath.row;
        cell.button.section = indexPath.section;
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
    
    // MARK: Button handlers
    @objc func buttonPressed(button: ListButton) {
        updateTable(after:) {
            if case .add(let item) = button.type {
                currentList.append(item);
                if (!items.contains(item)) {
                    items.append(item);
                }
                searchBar.text = "";
                searchFilter = "";
                tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .automatic);
            } else if case .get(let item) = button.type {
                if currentStore.getLocationOf(item) == nil {
                    self.performSegue(withIdentifier:"LocateItem", sender:item);
                    // FIXME: Must ask them which aisle to look in
                }
                print("currentList was \(currentList)")
                currentList = currentList.filter( { $0 != item } );
                print("currentList is now \(currentList)")
            }
        }
    }
    
    @objc func setLocationButtonPressed(button: UIButton) {
        self.performSegue(withIdentifier: "DetermineStore", sender: nil);
    }
    
    // MARK: UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateTable(after:) {
            searchFilter = searchText;
        }
    }
    
    func createStoreNamed(_ name: String) {
        storeNames.append(name);
    }
    
    func loadStoreNamed(_ name: String) -> Store {
        // FIXME: Load this from a file
        var s = Store(name:name);
        if (name == "Home") {
            s.setItemLocation("cat", to: "Lounge");
            s.setItemLocation("potato", to:"Kitchen");
            s.setItemLocation("leek", to: "Lounge");
            s.setItemLocation("Poop", to: "Toilet");
        }
        return s;
    }
    
    // MARK: - Navigation


    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        guard let navigationViewController = segue.destination as? UINavigationController else {
            print("Unexpected segue \(segue.destination)");
            return;
        }
        guard let locationViewController = navigationViewController.topViewController as? LocationViewController else {
            print("Unexpected segue \(String(describing: navigationViewController.topViewController))");
            return;
        }
        if (segue.identifier == "LocateItem") {
            guard let item = sender as? String else {
                print("Unexpected sender")
                return;
            }
            locationViewController.determineLocationOf(item, amongst: sections.filter( { $0 != "Unknown" } ), withTitle: "Location of \(item)", then: {
                let locatedItem = $0;
                let location = $1;
                self.updateTable(after:) {self.currentStore?.setItemLocation(locatedItem, to: location);}})
        } else if (segue.identifier == "DetermineStore") {
            locationViewController.determineLocationOf("", amongst:storeNames, withTitle: "Where are you?", then: {
                let location = $1;
                if self.storeNames.index(of:location) == nil {
                    self.createStoreNamed(location);
                }
                self.updateTable(after:) {self.currentStore = self.loadStoreNamed(location) }
            });
        }
    }
}
