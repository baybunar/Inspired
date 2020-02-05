//
//  ShareViewController.swift
//  InspiredShare
//
//  Created by Can Baybunar on 22.02.2019.
//  Copyright © 2019 Baybunar. All rights reserved.
//

import UIKit
import Social
import CoreData
import MobileCoreServices
import Firebase

struct CellProperties {
    var cellIdentifier: String
    var isExpandable: Bool
    var isExpanded: Bool = false
    var heightForRow: CGFloat
}

enum AddReminderValidationType {
    case Name
    case ReminderDesc
    case Image
    case ReminderDate
    case ReminderOption
}

class ShareViewController: UIViewController {
    
    let sharedImageKey = "ImageSharePhotoKey"
    let sharedNameKey = "ImageShareNameKey"
    let sharedDescKey = "ImageShareDescKey"
    let sharedFreqOptionKey = "ImageShareFreqOptionKey"
    let sharedDateOptionKey = "ImageShareDateOptionKey"
    let sharedTagOptionKey = "ImageShareTagKey"
    
    @IBOutlet weak var pickersTableView: UITableView!
    @IBOutlet weak var reminderImageView: UIImageView!
    @IBOutlet weak var reminderTextView: UITextView!
    @IBOutlet weak var reminderTextField: UITextField!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var tagTextField: UITextField!
    @IBOutlet weak var tagButton: UIButton!
    
    var selectedReminderType: String? = AddReminderFrequencyType.None.rawValue
    var selectedDate: Date? = Date()
    var selectedImage: Data!
    var tags: [NSManagedObject] = []
    var fbTagNames: [FBTag] = []
    var imagePicker = UIImagePickerController()
    let convertQueue = DispatchQueue(label: "convertQueue", attributes: .concurrent)
    let saveQueue = DispatchQueue(label: "saveQueue", attributes: .concurrent)
    
    var identifierList = [CellProperties(cellIdentifier: "AddReminderDateLabelTableViewCell", isExpandable:false, isExpanded:false, heightForRow: CGFloat(44)),
                          CellProperties(cellIdentifier:"AddReminderDatePickerTableViewCell", isExpandable:true, isExpanded:false, heightForRow: CGFloat(150)),
                          CellProperties(cellIdentifier:"AddReminderFrequencyLabelTableViewCell", isExpandable:false, isExpanded:false, heightForRow: CGFloat(44)),
                          CellProperties(cellIdentifier:"AddReminderPickerTableViewCell", isExpandable:true, isExpanded:false ,heightForRow: CGFloat(150))]
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        hideKeyboardWhenTappedAround()
        pickersTableView.tableFooterView = UIView(frame: .zero)
        pickersTableView.backgroundColor = UIColor(red: 222.0 / 255.0, green: 227.0 / 255.0, blue: 232.0 / 255.0, alpha: 1.0)        
        
        addButton.addTarget(self, action: #selector(self.saveFB), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(self.cancel), for: .touchUpInside)
        tagButton.addTarget(self, action: #selector(self.showTags), for: .touchUpInside)
        
        self.manageImage()
        
        getTags()
    }
    
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    
    func getVisibleCellsList() -> [CellProperties] {
        var visibleCellsList = [CellProperties]()
        for cellIdentifier in identifierList {
            if (cellIdentifier.isExpandable && cellIdentifier.isExpanded) || (!cellIdentifier.isExpandable && !cellIdentifier.isExpanded) {
                visibleCellsList.append(cellIdentifier)
            }
        }
        
        return visibleCellsList
    }
    
    @objc func cancel() {
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    @objc func save() {
        if let name = self.reminderTextField.text, let _ = self.selectedImage, let tag = self.tagTextField.text {
            
            let userDefaults = UserDefaults(suiteName: "group.com.baybunar.inspired")
            userDefaults?.set(name, forKey: self.sharedNameKey)
            userDefaults?.set(tag, forKey: self.sharedTagOptionKey)
            
            if let desc = self.reminderTextView.text {
                userDefaults?.set(desc, forKey: self.sharedDescKey)
            }
            
            if let freqOption = self.selectedReminderType {
                userDefaults?.set(freqOption, forKey: self.sharedFreqOptionKey)
            }
            
            if let dateOption = self.selectedDate {
                userDefaults?.set(dateOption, forKey: self.sharedDateOptionKey)
            }
            
            userDefaults?.synchronize()
            
            self.redirectToHostApp()
        } else {
            self.showValidationMessage()
        }
    }
    
    @objc func saveFB() {
        if let name = self.reminderTextField.text,
            let desc = self.reminderTextField.text,
            let remindDate = self.selectedDate,
            let _ = self.selectedImage {
            
            var fbReminder = FBReminder(name: name, desc: desc, reminderDate: DateUtils.sharedInstance.convertDateToString(date: remindDate), active: true, done: false)
            
            if let freqOption = self.selectedReminderType {
                fbReminder.repeatFrequency = freqOption
            }
            
            if let enteredTag = self.tagTextField.text, enteredTag != "" {
                if self.fbTagNames.count > 0 {
                    if let tagId = self.fbTagControl(enteredTag: enteredTag) {
                        fbReminder.tagId = tagId
                    } else {
                        if let tagId = self.addNewFBTag(tagName: enteredTag) {
                            fbReminder.tagId = tagId
                        }
                    }
                } else {
                    if let tagId = self.addNewFBTag(tagName: enteredTag) {
                        fbReminder.tagId = tagId
                    }
                }
            }
            
            self.uploadPhotoToFirebaseStorage() { url in
                fbReminder.reminderImageUrl = url
                let userDefaults = UserDefaults(suiteName: "group.com.baybunar.inspired")
                guard let userId = userDefaults?.object(forKey: "currentUserId") as? String else {
                    return
                }
                let refReminder = Database.database().reference(withPath: "reminders/\(userId)")
                refReminder.childByAutoId().setValue(fbReminder.toAnyObject())
                self.dismiss(animated: true, completion: nil)
                
                if let objectId = refReminder.key, let freqOption = self.selectedReminderType, freqOption != AddReminderFrequencyType.None.rawValue {
                    NotificationUtils.shared.scheduleNotification(objectId: objectId, name: name, desc: desc, freqOption: freqOption, date: remindDate)
                }
                //self.redirectToHostApp()
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            }
        } else {
            self.showValidationMessage()
        }
    }
    
    func showValidationMessage() {
        let alertController = UIAlertController(title: "Warning", message: "Please fill missing information.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        present(alertController, animated: true, completion: nil)
    }
    
    func redirectToHostApp() {
        let url = URL(string: "Inspired://dataUrl=\(sharedImageKey)")
        var responder = self as UIResponder?
        let selectorOpenURL = sel_registerName("openURL:")
        
        while (responder != nil) {
            if (responder?.responds(to: selectorOpenURL))! {
                let _ = responder?.perform(selectorOpenURL, with: url)
            }
            responder = responder!.next
        }
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    func manageImage() {
        let content = extensionContext!.inputItems[0] as! NSExtensionItem
        let contentType = kUTTypeImage as String
        
        for (_, attachment) in (content.attachments!).enumerated() {
            if attachment.hasItemConformingToTypeIdentifier(contentType) {
                
                attachment.loadItem(forTypeIdentifier: contentType, options: nil) { [weak self] data, error in
                    
                    if error == nil, let url = data as? URL, let this = self {
                        do {
                            let rawData = try Data(contentsOf: url)
                            let rawImage = UIImage(data: rawData)
                            
                            let image = UIImage.resizeImage(image: rawImage!, width: 400, height: 400)
                            let imgData = image.jpegData(compressionQuality: 1)
                            
                            DispatchQueue.main.async {
                                this.reminderImageView.image = image
                            }
                            this.selectedImage = imgData
                            
                            /*if index == (content.attachments?.count)! - 1 {
                                DispatchQueue.main.async {
                                    let userDefaults = UserDefaults(suiteName: "group.com.baybunar.inspired")
                                    userDefaults?.set(this.selectedImage, forKey: this.sharedImageKey)
                                    userDefaults?.synchronize()
                                }
                            }*/
                        }
                        catch let exp {
                            print("GETTING EXCEPTION \(exp.localizedDescription)")
                        }
                        
                    } else {
                        print("GETTING ERROR")
                        let alert = UIAlertController(title: "Error", message: "Error loading image", preferredStyle: .alert)
                        
                        let action = UIAlertAction(title: "Error", style: .cancel) { _ in
                            self?.dismiss(animated: true, completion: nil)
                        }
                        
                        alert.addAction(action)
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    func getTags() {
        FirebaseUtils.shared.getTagsEx { tags in
            self.fbTagNames = tags
        }
    }
    
    func fbTagControl(enteredTag: String) -> String? {
        var tagId: String? = nil
        let trimmedTag = enteredTag.trimmingCharacters(in: .whitespacesAndNewlines)
        for fbTag in fbTagNames {
            let fbTrimmedTag = fbTag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedTag == fbTrimmedTag {
                tagId = fbTag.tagId
            }
        }
        
        return tagId
    }
    
    func addNewFBTag(tagName: String) -> String? {
        guard let userId = UserDefaultsUtils.shared.readDefault(key: UserDefaultConstants.currentUser) as? String else {
            return nil
        }
        
        let fbTag = FBTag(name: tagName)
        let refTags = Database.database().reference(withPath: "tags/\(userId)").childByAutoId()
        refTags.setValue(fbTag.toAnyObject())
        
        return refTags.key
    }
    
    func uploadPhotoToFirebaseStorage(completion: @escaping (_ url: String?) -> Void) {
        if let imageName = FirebaseUtils.shared.createImageNameEx() {
            let storageRef = Storage.storage().reference().child(imageName)
            storageRef.putData(self.selectedImage, metadata: nil) { (metadata, error) in
                if error != nil {
                    completion(nil)
                } else {
                    storageRef.downloadURL { (url, error) in
                        guard let imageUrl = url else {
                            completion(nil)
                            return
                        }
                        completion(imageUrl.absoluteString)
                    }
                }
            }
        } else {
            completion(nil)
        }
    }
    
    @objc func showTags() {
        let storyBoard: UIStoryboard = UIStoryboard(name: "MainInterface", bundle: nil)
        let reminderTagsViewController = storyBoard.instantiateViewController(withIdentifier: "ShareTagsTableViewController") as! ShareTagsTableViewController
        reminderTagsViewController.delegate = self
        let backItem = UIBarButtonItem()
        reminderTagsViewController.navigationItem.backBarButtonItem = backItem
        
        navigationController?.pushViewController(reminderTagsViewController, animated: true)
    }
}

extension ShareViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getVisibleCellsList().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let visibleCellList = getVisibleCellsList()
        guard let cell = tableView.dequeueReusableCell(withIdentifier: visibleCellList[indexPath.row].cellIdentifier, for: indexPath) as? CustomTableViewCell else {
            return UITableViewCell()
        }
        
        if indexPath.row == 0 {
            if let dateSelected = self.selectedDate {
                cell.selectedDateLabel.text = DateUtils.sharedInstance.convertDateToString(date: dateSelected)
            }
        }
        
        if !identifierList[1].isExpanded {
            if indexPath.row == 1, let frequencySelected = self.selectedReminderType {
                cell.selectedFrequencyLabel.text = frequencySelected
            }
        } else {
            if indexPath.row == 2, let frequencySelected = self.selectedReminderType {
                cell.selectedFrequencyLabel.text = frequencySelected
            }
        }
        
        cell.delegate = self
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return getVisibleCellsList()[indexPath.row].heightForRow
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let rowIndex = indexPath.row
        var rowIndexFull: Int
        if identifierList[1].isExpanded {
            rowIndexFull = rowIndex + 1
        } else {
            rowIndexFull = (2 * rowIndex) + 1
        }
        
        let cellIdentifier = getVisibleCellsList()[rowIndex]
        if !cellIdentifier.isExpandable {
            if identifierList[rowIndexFull].isExpanded {
                identifierList[rowIndexFull].isExpanded = false
            } else {
                identifierList[rowIndexFull].isExpanded = true
            }
        }
        
        pickersTableView.reloadSections(IndexSet(integer: 0), with: .fade)
    }
}

extension ShareViewController: CustomTableViewCellProtocol {
    
    func dateSelected(selectedDate: Date) {
        self.selectedDate = selectedDate
        if let dateLabelCell = pickersTableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? CustomTableViewCell {
            dateLabelCell.selectedDateLabel.text = DateUtils.sharedInstance.convertDateToString(date: selectedDate)
        }
        
    }
    
    func optionSelected(selectedOption: String) {
        self.selectedReminderType = selectedOption
        var pickerLabelIndex = 1
        if identifierList[1].isExpanded {
            pickerLabelIndex = 2
        }
        if let pickerLabelCell = pickersTableView.cellForRow(at: IndexPath(row: pickerLabelIndex, section: 0)) as? CustomTableViewCell {
            pickerLabelCell.selectedFrequencyLabel.text = selectedOption
        }
    }
    
}

extension UIImage {
    class func resizeImage(image: UIImage, width: CGFloat, height: CGFloat) -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
}

extension ShareViewController: ShareReminderTagsSelectedProtocol {

    func fbTagSelected(selectedTag: FBTag) {
        self.tagTextField.text = selectedTag.name
    }
}
