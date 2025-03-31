//
//  IndexTestsViewController.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/12/2.
//

import UIKit
import CoreData

class IndexTestsViewController: UIViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
  }
  
  var container: NSPersistentContainer!
  
  @IBAction func clickConnect(_ sender: UIButton) {
    container = AppDelegate.current.persistentContainer
  }
  
  @IBAction func clickInsertion(_ sender: Any) {
    try! insert(chatID: 1, messageCount: 100)
  }
  
  @IBAction func clickSearch(_ sender: Any) {
    let context = AppDelegate.current.persistentContainer.viewContext
//    let request = Message.fetchRequest()
//    request.predicate = NSPredicate(format: "timestamp == NULL")
//    let results = try! context.fetch(request)
//    print(results)
    
//    let request = Media.fetchRequest()
//    request.predicate = NSPredicate(format: "timestamp != 0")
//    let results = try! context.fetch(request)
//    print(results)
  }
  
  // MARK: - Tools
  
  private func insert(chatID: Int64, messageCount: Int) throws {
    let context = AppDelegate.current.persistentContainer.viewContext
    
    let chat = Chat(context: context)
    chat.name = "TestChat \(chatID)"
    chat.chatID = chatID
    
//    var lastMessage: Message? = nil
//    for msgid in 0..<(0 + UInt64(messageCount)) {
//      let message = Message.init(context: context)
//      message.messageID = Int64(msgid)
//      message.content = Data()
//      message.text = "\(msgid) - try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)"
//      lastMessage = message
//    }
//    
//    chat.lastMessage = lastMessage
    
    try context.save()
    context.reset()
  }
  
  /*
   // MARK: - Navigation
   
   // In a storyboard-based application, you will often want to do a little preparation before navigation
   override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
   // Get the new view controller using segue.destination.
   // Pass the selected object to the new view controller.
   }
   */
  
}
