//
//  ListViewController.swift
//  schindler3
//
//  Created by Matt Lilley on 17/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//
// TODO List:
//    Expose the database for copying on/off device
//    Queue the messages to be sent
//    Send and process messages when network is online

import UIKit
import CoreLocation;

class ListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, CLLocationManagerDelegate {

    //MARK: Properties
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var setLocationButton: UIBarButtonItem!
    @IBOutlet weak var syncButton: UIBarButtonItem!
    
    private var locations: [String: [String]] = [:];
    private var sections: [String] = [];
    private var searchFilter: String = "";
    private var locationManager = CLLocationManager();
    private var currentLocation: (Double, Double) = (0,0);
    private var dataManager = DataManager();
    
    
    //MARK: Methods
    
    func movedStore(to store_id: String) {
        navigationItem.title = store_id;
    }
    
    func indicateConnected() {
        navigationController?.navigationBar.barTintColor = UIColor.green
    }
    
    func indicateDisconnected() {
        navigationController?.navigationBar.barTintColor = UIColor.red
    }
    
    private func debug(_ message:String) {
        //print(message)
    }
    
    private func updateTableView() {
        let temporaryItem = searchFilter;
        let filter = searchFilter.lowercased();
        let deferredItems = dataManager.deferredItems()
        var newLocations: [String: [String]] = [:];
        // The list has a temporary item if the search bar is not empty and the thing in the search bar doesn't match anything in the list
        let hasTemporaryItem = filter != "" && !dataManager.itemExists(filter);
        for item in hasTemporaryItem ? dataManager.getItems() + [temporaryItem] : dataManager.getItems() {
            if (filter != "" && !item.lowercased().contains(filter)) {
                // The filter is not empty and this item does not match the filter. Do not include it.
                continue;
            }
            if (filter == "" && !dataManager.getCurrentList().contains(item)) {
                // The filter IS empty so we only want to display items actually on the current list
                continue;
            }
            if (deferredItems.contains(item)) {
                // The item is deferred. Skip it
                continue
            }
            print("Must display \(item)")
            if let aisle = dataManager.currentStore.getLocationOf(item) {
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

        // Table update is hard to get your head around. The general idea is:
        // * First all the row deletes are processed
        // * Next, all the section deletes are processed
        // * Then, the row inserts are processed
        // * Finally, if any sections have been added they are loaded
        
        let (deletedSections, insertedSections) = changesBetween(sections, and:newSections);
        debug("Updated Locations: \(newLocations)")
        debug("Sections is changing from \(sections) to \(newSections), and in the process, changing as follows:")
        debug("   * Deleted sections: \(deletedSections)");
        debug("   * Inserted sections: \(insertedSections)");
        for sectionTitle in Set(sections).intersection(Set(newSections)) {
            debug("Section \(sectionTitle) is changing from \(locations[sectionTitle]!) to \(newLocations[sectionTitle]!)")
            let (deletedRows, insertedRows) = changesBetween(locations[sectionTitle]!, and:newLocations[sectionTitle]!);
            let sectionIndex = sections.index(of: sectionTitle)!;
            let newSectionIndex = newSections.index(of: sectionTitle)!
            let modifiedRows = Set(deletedRows).intersection(Set(insertedRows));
            let onlyDeletedRows = Set(deletedRows).subtracting(modifiedRows);
            let onlyInsertedRows = Set(insertedRows).subtracting(modifiedRows);
            debug("   * Section \(sectionTitle) (was index \(sectionIndex) but is now \(newSectionIndex))");
            debug("      * Deleted \(onlyDeletedRows) from section \(sectionIndex)");
            debug("      * Inserted \(onlyInsertedRows) to section \(newSectionIndex)");
            debug("      * Updated \(modifiedRows) on section \(sectionIndex)");
            tableView.deleteRows(at: onlyDeletedRows.map({IndexPath.init(row: $0, section:sectionIndex)}), with:.automatic);
            tableView.insertRows(at: onlyInsertedRows.map({IndexPath.init(row: $0, section:newSectionIndex)}), with:.automatic);
            tableView.reloadRows(at: modifiedRows.map({IndexPath.init(row: $0, section:sectionIndex)}), with:.none);
        }
        tableView.deleteSections(deletedSections, with:.automatic);
        tableView.insertSections(insertedSections, with:.automatic);
        locations = newLocations;
        sections = newSections;
        print("Committing changes...");
        tableView.endUpdates();
        //tableView.reloadData();
    }
    
    func login() {
        let defaults = UserDefaults.standard
        if let userId = defaults.string(forKey:"user_id"), let password = defaults.string(forKey:"password") {
            dataManager.configure(userId, password)
        } else {
            self.performSegue(withIdentifier: "Login", sender: nil);
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("main view has loaded")
        dataManager.setDelegate(self)
        login()
        
       // tableView.tableFooterView = UIView();
        updateTable(after:) {
            dataManager.currentStore = dataManager.loadStoreNamed("Home");
        }
        self.locationManager.requestWhenInUseAuthorization();
        if CLLocationManager.locationServicesEnabled() {
            print("Tracking location...")
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        } else {
            print("Location is not allowed");
        }
        searchBar.delegate = self;
        setLocationButton.target = self;
        setLocationButton.action = #selector(ListViewController.setLocationButtonPressed(button:));
        syncButton.target = self;
        syncButton.action = #selector(ListViewController.syncButtonPressed(button:));
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
        //print("Request for item at section \(indexPath.section), row \(indexPath.row): item \(items[indexPath.row]) This section contains \(items)");
        cell.label.text = items[indexPath.row];
        if (dataManager.getCurrentList().contains(items[indexPath.row])) {
            cell.button.type = .get(items[indexPath.row]);
        } else {
            cell.button.type = .add(items[indexPath.row]);
        }
        cell.button.addTarget(self, action:#selector(ListViewController.buttonPressed(button:)), for: .touchUpInside);
        return cell;
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section];
    }
    
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let section = sections[indexPath.section];
        guard let items = locations[section] else {
            fatalError("Request for non-existent section \(section)?");
        }
        let item = items[indexPath.row];
        let removeAction = UIContextualAction(style: .normal, title: "Remove") { (action, view, handler) in
            print("Remove Action Tapped");
            self.updateTable {
                self.dataManager.move(item:item, toUnknownLocationAtStore:self.dataManager.currentStore.name);
            }
            handler(true);
        }
        let deferAction = UIContextualAction(style: .normal, title: "Defer") { (action, view, handler) in
            self.updateTable {
                self.dataManager.deferItem(item:item);
            }
            handler(true);
        }
        removeAction.backgroundColor = .red;
        deferAction.backgroundColor = .green;
        let configuration: UISwipeActionsConfiguration;
        if section == "Unknown" {
            configuration = UISwipeActionsConfiguration(actions: [deferAction])
        } else {
            configuration = UISwipeActionsConfiguration(actions: [removeAction, deferAction]);
        }
        configuration.performsFirstActionWithFullSwipe = false;
        return configuration
    }
    
    func updateTable(after: () -> Void) {
        tableView.beginUpdates()
        after();
        updateTableView();
    }
    
    // MARK: Button handlers
    @objc func buttonPressed(button: ListButton) {
        updateTable(after:) {
            if case .add(let item) = button.type {
                dataManager.addItemToList(named: item);                
                searchBar.text = "";
                searchFilter = "";
                print("Reloading row \(button.row) in section \(button.section)")
                tableView.reloadRows(at: [IndexPath(row: button.row, section: button.section)], with: .automatic);
            } else if case .get(let item) = button.type {
                if dataManager.currentStore.getLocationOf(item) == nil {
                    self.performSegue(withIdentifier:"LocateItem", sender:item);
                }
                dataManager.deleteListItem(named: item);
            }
        }
    }
    
    @objc func setLocationButtonPressed(button: UIButton) {
        self.performSegue(withIdentifier: "DetermineStore", sender: nil);
    }

    @objc func syncButtonPressed(button: UIButton) {
        // FIXME: Implement manual sync
    }

    
    // MARK: UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateTable(after:) {
            searchFilter = searchText;
        }
    }
    
    // MARK: CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation: CLLocation = manager.location else { return }
        let distanceInMetres = newLocation.distance(from:CLLocation(latitude: currentLocation.0, longitude: currentLocation.1))
        if distanceInMetres > 100 {
            print("You have moved from \(currentLocation.0),\(currentLocation.1) to \(newLocation.coordinate.latitude),\(newLocation.coordinate.longitude), a distance of \(distanceInMetres)m")
            currentLocation = (newLocation.coordinate.latitude, newLocation.coordinate.longitude);
            updateTable(after:) {
                dataManager.determineStore(near:currentLocation);
            }
        }
    }
    
    // MARK: - Navigation


    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if let loginViewController = segue.destination as? LoginViewController {
            loginViewController.delegate = self;
            return
        }
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
                self.updateTable(after:) {
                    self.dataManager.setLocationOf(item: locatedItem, atStore: self.dataManager.currentStore.name, toLocation: location)
                    //self.dataManager.currentStore?.setItemLocation(locatedItem, to: location);
                    
                }})
        } else if (segue.identifier == "DetermineStore") {
            locationViewController.determineLocationOf("", amongst:dataManager.getStoreList().sorted(), withTitle: "Where are you?", then: {
                let location = $1;
                self.dataManager.setLocationOf(store: location, to:self.currentLocation);                
                self.updateTable(after:) {
                    self.dataManager.determineStore(near:self.currentLocation);
                }            
            });
        }
    }
}
