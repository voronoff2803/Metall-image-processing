//
//  FilterSettingsTableViewController.swift
//  Multimedia
//
//  Created by Alexey Voronov on 22/04/2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

import UIKit

class FilterSettingsTableViewController: UITableViewController {

    var data: [String] = []
    var filter: FilterView?
    var delegate: FilterSettingsTableViewControllerDelegate?
    var usingForIndex: Int = 0
    let cellReuseIdentifier = "cell"
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Filter settings"
        
        if usingForIndex == 0 {
            self.title = filter?.kernelName
        }
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return data.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        // set the text from the data model
        cell.textLabel?.text = self.data[indexPath.row]
        if usingForIndex == 0 && indexPath.row == 0 {
            if let currentFilter = filter?.parentFilter {
                cell.textLabel?.text = self.data[indexPath.row] + " = " + currentFilter.kernelName + " | " + currentFilter.info
            }
        }
        if usingForIndex == 0 && indexPath.row == 1 {
            if let currentFilter = filter?.parentFilter2 {
                cell.textLabel?.text = self.data[indexPath.row] + " = " + currentFilter.kernelName + " | " + currentFilter.info
            }
        }
        if usingForIndex == 0 && indexPath.row == 2 {
            if let currentFilter = filter?.parentFilter3 {
                cell.textLabel?.text = self.data[indexPath.row] + " = " + currentFilter.kernelName + " | " + currentFilter.info
            }
        }
        if usingForIndex == 0 && indexPath.row == 3 {
            if let currentFilter = filter?.parentFilter4 {
                cell.textLabel?.text = self.data[indexPath.row] + " = " + currentFilter.kernelName + " | " + currentFilter.info
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        delegate!.selectItem(index: indexPath.row, usingForIndex: usingForIndex)
        if usingForIndex == 1 {
            usingForIndex = 0
            self.navigationController?.popViewController(animated: true)
        }
        if usingForIndex == 2 {
            usingForIndex = 0
            self.navigationController?.popViewController(animated: true)
        }
    }
}

protocol FilterSettingsTableViewControllerDelegate {
    func selectItem(index: Int, usingForIndex: Int)
}
