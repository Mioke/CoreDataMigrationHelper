//
//  GRDBTestingViewController.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/1/21.
//

import Foundation
import UIKit
import GRDB

class GRDBTestingViewController: UIViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
  }
  
  var dbPool: DatabasePool? = nil
  
  @IBAction func clickOpenDB(_ sender: Any) {
    let path = AppDelegate.current.storeURL.path
    do {
      dbPool = try DatabasePool(path: path)
    } catch {
      print(error)
    }
    
    guard let dbPool else { return }
    let messages = try! dbPool.read { db in
      try _ZMessage.fetchAll(db)
    }
    
    print(messages.count)
  }
  
  @IBAction func clickCreateTempDB(_ sender: Any) {
    let path = NSTemporaryDirectory() + "test.sqlite"
    do {
      let pool = try DatabasePool(path: path)
      print("temp db path: ", path)
      
      try pool.writeInTransaction { db in
        try db.execute(sql: """
          CREATE TABLE IF NOT EXISTS ZMESSAGE ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZCHATID INTEGER, ZMESSAGEID INTEGER, ZOPTIONS INTEGER, ZTIMESTAMP INTEGER, ZLASTMESSAGEOF INTEGER, ZTEXT VARCHAR, ZCONTENT BLOB )
          """)
        
        let message = _ZMessage()
        try message.insert(db, onConflict: .replace)
        
        return .commit
      }
    } catch {
      print(error)
    }
    
  }
  
  @IBAction func clickTestRelationship(_ sender: Any) {
    let path = AppDelegate.current.storeURL.path
    do {
      let pool = try DatabasePool(path: path)
      try pool.read { db in
        if let chat = try _ZChat.fetchOne(db) {
          try chat.populateRelationships(in: db)
          print(chat.lastMessaage?.text as Any)
        }
      }
    } catch {
      print(error)
    }
  }
  
  @IBAction func clickAddChatWithUsers(_ sender: Any) {
    let context = AppDelegate.current.persistentContainer.viewContext
    var users = Array<User>()
    for uid in 1...10 {
      let request = User.fetchRequest()
      request.predicate = NSPredicate(format: "uid == %d", uid)
      if let user = try? context.fetch(request).first {
        users.append(user)
      } else {
        let user = User(context: context)
        user.uid = Int64(uid)
        user.name = "user \(uid)"
        users.append(user)
      }
    }
    
    let chat1 = Chat(context: context)
    chat1.chatID = 10001
    chat1.name = "chat has users1"
    chat1.users = NSSet(array: users)
    
    let chat = Chat(context: context)
    chat.chatID = 10002
    chat.name = "chat has users2"
    chat.users = NSSet(array: users)
    
    try! context.save()
  }
  
  @IBAction func clickQueryChats(_ sender: Any) {
    let context = AppDelegate.current.persistentContainer.viewContext
    
    let chatRequest1 = Chat.fetchRequest()
    chatRequest1.relationshipKeyPathsForPrefetching = ["users"]
    chatRequest1.predicate = NSPredicate(format: "chatID == %d", 10001)
    if let chat1 = try! context.fetch(chatRequest1).first, let users = chat1.users as? Set<User> {
      for user in users {
        print(user)
      }
    }
    
    let chatRequest2 = Chat.fetchRequest()
    chatRequest2.relationshipKeyPathsForPrefetching = ["users"]
    chatRequest2.predicate = NSPredicate(format: "chatID == %d", 10002)
    if let chat2 = try! context.fetch(chatRequest2).first, let users = chat2.users as? Set<User>  {
      for user in users {
        print(user)
      }
    }
  }
  
  @IBAction func clickAddUser(_ sender: Any) {
    let context = AppDelegate.current.persistentContainer.viewContext
    let user = User(context: context)
    user.uid = 99
    user.name = "user 99"
    try? context.save()
  }
  
  
  @IBAction func clickGRDBInit(_ sender: Any) {
    let store = try! DemoStore()
    
    let chats = try! store.pool.read { db in
      try _ZChat.fetchAll(db)
    }
    
    print(chats.count)
  }
  
  
}
