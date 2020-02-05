//
//  ShareTagsTableViewController.swift
//  InspiredShare
//
//  Created by Can Baybunar on 19.10.2019.
//  Copyright © 2019 Baybunar. All rights reserved.
//

import UIKit

protocol ShareReminderTagsSelectedProtocol: class {
    func fbTagSelected(selectedTag: FBTag)
}

class ShareTagsTableViewController: UITableViewController {

    var fbTags: [FBTag] = []
    var delegate: ShareReminderTagsSelectedProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView(frame: .zero)
        getTags()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fbTags.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ShareTagsTableViewCell", for: indexPath) as UITableViewCell
        
        let tag = fbTags[indexPath.row] as FBTag
        cell.textLabel?.text = tag.name
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.fbTagSelected(selectedTag: fbTags[indexPath.row])
        navigationController?.popViewController(animated: true)
    }
    
    func getTags() {
       FirebaseUtils.shared.getTagsEx { tags in
            self.fbTags = tags
            self.tableView.reloadData()
        }
    }

}
