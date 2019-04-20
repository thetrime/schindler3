//
//  SecondaryTableControllerViewController.swift
//  schindler3
//
//  Created by Matt Lilley on 21/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

import UIKit

class LocationViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var skipButton: UIBarButtonItem!
    var items: [String] = [];
    var filteredItems: [String] = [];
    var stores: [String] = ["Home"]
    private var filter: String = "";
    private var key: String = "";
    private var callback: ((String, String)->())!;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self;
        updateTable(after:) {
            filter = "";
        }
        skipButton.target = self;
        skipButton.action = #selector(LocationViewController.skipButtonPressed(button:));
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func determineLocationOf(_ item: String, amongst choices: [String], withTitle title:String, then:@escaping (String, String)->() ) -> () {
        navigationItem.title = title;
        key = item;
        items = choices;
        callback = then;
        print("Set callback to \(callback!)")
    }
    
    private func updateTableRows() {
        var newFilteredItems: [String] = [];
        let lowerFilter = filter.lowercased();
        if (filter != "" && !items.contains(where:{$0.caseInsensitiveCompare(filter) == .orderedSame})) {
            newFilteredItems.append(filter)
        }
        for item in items {
            if (filter == "") {
                newFilteredItems.append(item)
            } else if (item.lowercased().contains(lowerFilter)) {
                newFilteredItems.append(item);
            }
        }
        print("\(filteredItems) -> \(newFilteredItems)");
        let (deletedRows, insertedRows) = changesBetween(filteredItems, and:newFilteredItems);
        let modifiedRows = Set(deletedRows).intersection(Set(insertedRows));
        let onlyDeletedRows = Set(deletedRows).subtracting(modifiedRows);
        let onlyInsertedRows = Set(insertedRows).subtracting(modifiedRows);
        tableView.deleteRows(at: onlyDeletedRows.map({IndexPath.init(row: $0, section:0)}), with:.automatic);
        tableView.insertRows(at: onlyInsertedRows.map({IndexPath.init(row: $0, section:0)}), with:.automatic);
        tableView.reloadRows(at: modifiedRows.map({IndexPath.init(row: $0, section:0)}), with:.none);
        filteredItems = newFilteredItems;
        tableView.endUpdates();
    }
    
    func updateTable(after: () -> Void) {
        tableView.beginUpdates();
        after();
        updateTableRows();
    }
    
    // MARK: UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateTable(after:) { filter = searchText; }
    }
    
    // MARK: UITableViewDelegate
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "ListItemTableViewCell";
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ListItemTableViewCell  else {
            fatalError("The dequeued cell is not an instance of ListItemTableViewCell.")
        }
        print("Request for location \(indexPath.row).");
        cell.label.text = filteredItems[indexPath.row]
        if (indexPath.row == 0 && filter != "" && !items.contains(where:{$0.caseInsensitiveCompare(filter) == .orderedSame})) {
            cell.button.type = .add(filteredItems[indexPath.row]);
        } else {
            cell.button.type = .set(filteredItems[indexPath.row]);
        }
        cell.button.addTarget(self, action:#selector(LocationViewController.buttonPressed(button:)), for: .touchUpInside);
        return cell;
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("Request for count: \(filteredItems.count)")
        return filteredItems.count;
    }

    // MARK: Button handling
    @objc func buttonPressed(button: ListButton) {
        // FIXME: Handle add/set event here
        if case .set(let location) = button.type {
            print("Calling callback \(callback)")
            callback(key, location);
            dismiss(animated: true, completion: nil);
        } else if case .add(let location) = button.type {
            print("Calling callback \(callback)")
            callback(key, location);
            dismiss(animated: true, completion: nil);
        }
    }

    @objc func skipButtonPressed(button: UIButton) {
        // Just the same, only do not call the callback
        dismiss(animated: true, completion: nil);
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
 */

}
