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
//    let path = AppDelegate.current.storeURL.path
//    do {
//      let pool = try DatabasePool(path: path)
//      try pool.read { db in
//        if let chat = try _ZChat.fetchOne(db) {
//          try chat.populateRelationships(in: db)
//          print(chat.lastMessaage?.text as Any)
//        }
//      }
//    } catch {
//      print(error)
//    }
    
    let context = AppDelegate.current.persistentContainer.viewContext
    
    let message = Message(context: context)
    message.messageID = 1
    message.content = Data()
    
    for messageID in 2...3 {
      let reply = ThreadReply(context: context)
      reply.messageID = Int64(messageID)
      reply.rootMessage = message
    }
    
    try! context.save()
    
    print(message.replies as Any)
    
//    let newReply = ThreadReply(context: context)
//    newReply.messageID = 4
//    newReply.rootMessage = message
//    
//    try! context.save()
    
    message.replies = NSSet(array: message.replies!.filter({ ($0 as! ThreadReply).messageID != 3 }))
    
    try! context.save()
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
  
  let store = try! DemoStore()
  
  @IBAction func clickGRDBInit(_ sender: Any) {
    
    let chats = try! store.pool.read { db in
      try _ZChat.fetchAll(db)
    }
    
    print(chats.count)
  }
  
  @IBAction func clickAddGRDBMessage(_ sender: Any) {
    try! store.pool.write { db in
      let message = _ZMessage()
      message.messageID = 1
      message.text = "hello world"
      try message.create(in: db, context: store.database)
      // after create, the message can only have a primary key, so here must create first.
      
      let reply1 = ZThreadReply()
      reply1.messageID = 2
      reply1.rootMessage = message
      try reply1.create(in: db, context: store.database)
    }
    
    try! store.pool.read({ db in
      var request = FetchRequest<_ZMessage>.init(prediction: _ZMessage.filter(_ZMessage.Column.messageID == 1))
      request.prefetchingRelationships = [_ZMessage.repliesRelationship.relationshipName]
      
      if let message = try request.fetchOne(db) {
        print(message.replies as Any)
      }
    })
  }
  
}
