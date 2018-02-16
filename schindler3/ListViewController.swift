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
    var items = [Item]();
    
    //MARK: Methods
    private func loadItems() {
        for i in 0...5 {
            let item = Item(name:"Foo Item \(i)");
            items.append(item);
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        loadItems();
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: UITableViewDelegate
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "ListItemTableViewCell";
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ListItemTableViewCell  else {
            fatalError("The dequeued cell is not an instance of ListItemTableViewCell.")
        }
        let item = items[indexPath.row];
        cell.label.text = item.name;
        return cell;
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
