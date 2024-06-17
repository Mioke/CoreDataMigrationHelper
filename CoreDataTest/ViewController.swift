//
//  ViewController.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/4/8.
//

import UIKit
import CoreData
import CoreText

class ViewController: UIViewController, ManualMigratorEventDelegate {
  
  @IBOutlet weak var textView: UITextView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
  }
  
  
  @IBAction func clickInsert(_ sender: Any) {
    insertMessageData()
//    insertMessage(with: 1_000_000)
  }
  
  private var messageCounter: UInt64 = 0
  
  func insertMessageData() {
    let context = AppDelegate.current.persistentContainer.viewContext
    
    print("begin insertion")
    
    let chat = Chat(context: context)
    chat.name = "TestChat"
    chat.chatID = 1
    
    let count = 100
    
    guard let gifURL = Bundle.main.url(forResource: "data", withExtension: "gif"),
          let textURL = Bundle.main.url(forResource: "text", withExtension: "log")
    else {
      fatalError()
    }
    
    var lastMessage: Message? = nil
    for msgid in messageCounter..<(messageCounter + UInt64(count)) {
        let message = Message.init(context: context)
        message.messageID = Int64(msgid)
        message.content = Data()
        message.text = try! String.init(contentsOf: textURL)
        lastMessage = message
    }
    
    chat.lastMessage = lastMessage
    try! context.save()
    
    messageCounter += UInt64(count)
    
    print("end insertion")
  }
  
  func insertMessage(with count: UInt64) {
    let context = AppDelegate.current.persistentContainer.viewContext
    
    print("begin insertion")
    
    // No different, still run insert one by one.
    let request = NSBatchInsertRequest(entity: Message.entity(), managedObjectHandler: { [self] object in
      if messageCounter >= count { return true }
      
      defer { messageCounter += 1}
      
      if let object = object as? Message {
        object.chatID = 1
        object.messageID = Int64(messageCounter)
        object.content = Data()
        object.text = "\(messageCounter) - try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)"
      }
      
      return false
    })
    
    let result = try! context.execute(request)
    if let result = result as? NSBatchInsertResult {
//       let ids = result.result as? [NSManagedObjectID] {
      print(result.resultType.rawValue)
    }
    
    try? context.save()
    messageCounter += count
    
    print("end insertion")
  }
  
  @IBAction func clickLight(_ sender: Any) {
    let container = NSPersistentContainer(name: "CoreDataTest")
    container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
    container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true
    container.persistentStoreDescriptions.first?.url = AppDelegate.current.storeURL
    
    container.loadPersistentStores { descriptor, error in
      if let error {
        print(error)
      } else {
        print("lightweight migration done.")
      }
    }
  }
  
  @IBAction func clickCheck(_ sender: Any) {
    let storeURL = AppDelegate.current.storeURL
    let meta = try! NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: storeURL)
    
    let modelURL = Bundle.main.url(forResource: "CoreDataTest", withExtension: "momd")!
    let model = NSManagedObjectModel.init(contentsOf: modelURL)!
    
    let isCompatible = model.isConfiguration(withName: nil, compatibleWithStoreMetadata: meta)
    
    print("is compatible: ", isCompatible)
  }
  
  // staged
  @IBAction func clickStart(_ sender: Any) {
    guard let momdURL = Bundle.main.url(forResource: "CoreDataTest", withExtension: "momd") else { fatalError() }
    let model1URL = momdURL.appending(component: "CoreDataTest.mom")
    let model2URL = momdURL.appending(component: "CoreDataTest v2.mom")
    guard let model1 = NSManagedObjectModel(contentsOf: model1URL) else { fatalError() }
    guard let model2 = NSManagedObjectModel(contentsOf: model2URL) else { fatalError() }
    
    let v1ModelChecksum = model1.versionChecksum
    let v1ModelReference = NSManagedObjectModelReference(model: model1, versionChecksum: v1ModelChecksum)
    
    let v2ModelChecksum = model2.versionChecksum
    let v2ModelReference = NSManagedObjectModelReference(model: model2, versionChecksum: v2ModelChecksum)
    
    
//    let lightweightStage = NSLightweightMigrationStage([v1ModelChecksum])
//    lightweightStage.label = "V1 to V2: Add flightData attribute"
    
    let customStage = NSCustomMigrationStage(
      migratingFrom: v1ModelReference,
      to: v2ModelReference
    )
    
    customStage.willMigrateHandler = { manager, stage in
      guard let container = manager.container else { fatalError() }
      print("do nothing")
      try container.viewContext.save()
    }
    
    let manager = NSStagedMigrationManager([customStage])
    
    let container = NSPersistentContainer(name: "CoreDataTest")
    guard let storeDescription = container.persistentStoreDescriptions.first else { fatalError() }
    storeDescription.url = AppDelegate.current.storeURL
    storeDescription.shouldMigrateStoreAutomatically = true
    storeDescription.shouldInferMappingModelAutomatically = true
    storeDescription.setOption(manager, forKey: NSPersistentStoreStagedMigrationManagerOptionKey)
    
    container.loadPersistentStores { description, maybeError in
      if let error = maybeError {
        fatalError("failed with error: \n\(error)")
      }
    }
    
  }
  
  @IBAction func clickManual(_ sender: Any) {
    manualMigration()
  }
  
  func manualMigration() {
    
    let destinationModelURL = Bundle.main.url(forResource: "CoreDataTest", withExtension: "momd")!
    let destinationModel = NSManagedObjectModel.init(contentsOf: destinationModelURL)!
    
    let sourceURL = AppDelegate.current.storeURL
    let sourceMeta = try! NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: sourceURL)
    
    guard let sourceModel = NSManagedObjectModel.mergedModel(from: nil, forStoreMetadata: sourceMeta) else { fatalError() }
    
    let manager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
    let mapping = try! NSMappingModel.inferredMappingModel(forSourceModel: sourceModel, destinationModel: destinationModel)
    
    let targetURL = AppDelegate.current.storeURL.deletingLastPathComponent().appending(path: "CoreDataTest-temp.sqlite")
    try! manager.migrateStore(from: sourceURL,
                              type: .sqlite,
                              mapping: mapping,
                              to: targetURL,
                              type: .sqlite)
    
    try! FileManager.default.removeItem(at: sourceURL)
    try! FileManager.default.moveItem(at: targetURL, to: sourceURL)
  }
  
  @IBAction func clickPagination(_ sender: Any) {
    paginationMigration()
  }
  
  func paginationMigration() {
//    let destinationModelURL = Bundle.main.url(forResource: "CoreDataTest", withExtension: "momd")!
//    let destinationModel = NSManagedObjectModel.init(contentsOf: destinationModelURL)!
//    
//    let sourceURL = AppDelegate.current.storeURL
//    let sourceMeta = try! NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: sourceURL)
//    
//    guard let sourceModel = NSManagedObjectModel.mergedModel(from: nil, forStoreMetadata: sourceMeta) else { fatalError() }
//    
//    let manager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
//    if let messageEntity = sourceModel.entitiesByName["Message"] {
//      print(messageEntity)
//    }
    
    print("begin pagination migration - \(Date())"); defer { print("end pagination migration - \(Date())") }
    
    guard let mappingURL = Bundle.main.url(forResource: "v1_to_v2", withExtension: "cdm"),
          let mapping = NSMappingModel.init(contentsOf: mappingURL)
    else {
      fatalError()
    }
    
    guard let entityMapping = mapping.entityMappingsByName["MessageToMessage"] else {
      fatalError()
    }
    
    let total = 1_000_000
    let pageCount = 10_000
    var currentPage = 1
    
    while currentPage * pageCount < total {
      currentPage += 1
      
      let p2 = entityMapping.copy() as! NSEntityMapping
      p2.name = "MessageV1ToMessageV2_p\(currentPage)"
      
      if let sourceExpression = entityMapping.sourceExpression as? NSFetchRequestExpression {
        
        let messageConst = NSExpression.init(forConstantValue: "Message")
        let condition = NSExpression.init(forConstantValue: "messageID < \(currentPage * pageCount)")
        let fetchRequest = NSExpression(
          forFunction: sourceExpression.requestExpression.operand,
          selectorName: sourceExpression.requestExpression.function,
          arguments: [messageConst, condition])
        
        p2.sourceExpression = NSFetchRequestExpression.expression(
          forFetch: fetchRequest,
          context: sourceExpression.contextExpression,
          countOnly: sourceExpression.isCountOnlyRequest)
      } else {
        fatalError()
      }
      
      mapping.entityMappings.append(p2)
    }
    
    
    let destinationModelURL = Bundle.main.url(forResource: "CoreDataTest", withExtension: "momd")!
    let destinationModel = NSManagedObjectModel.init(contentsOf: destinationModelURL)!
    
    let sourceURL = AppDelegate.current.storeURL
    let sourceMeta = try! NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: sourceURL)
    
    guard let sourceModel = NSManagedObjectModel.mergedModel(from: nil, forStoreMetadata: sourceMeta) else { fatalError() }
    
    let manager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
    
    let targetURL = AppDelegate.current.storeURL.deletingLastPathComponent().appending(path: "CoreDataTest-temp.sqlite")
    try! manager.migrateStore(
      from: sourceURL,
      type: .sqlite,
      mapping: mapping,
      to: targetURL,
      type: .sqlite
    )
    
    
//    let container = NSPersistentContainer(name: "CoreDataTest")
//    
//    let options = [
//      NSMigratePersistentStoresAutomaticallyOption: true, // automatically start the migration process
//      NSInferMappingModelAutomaticallyOption: false // not to infer mapping model, use mapping model in main bundle.
//    ]
//    _ = try! container.persistentStoreCoordinator.addPersistentStore(type: .sqlite, at: AppDelegate.current.storeURL, options: options)
    
  
  }
  
  @IBAction func clickUserV1Load(_ sender: Any) {
    useOldModelToRead()
  }
  
  func useOldModelToRead() {
//    print(Bundle.main.bundleURL)
    guard let oldModelURL = Bundle.main.url(forResource: "CoreDataTest", withExtension: "momd")?.appendingPathComponent("CoreDataTest.mom"),
          let model = NSManagedObjectModel(contentsOf: oldModelURL)
    else { fatalError() }
//    print(oldModelURL)
    
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    let options = [NSMigratePersistentStoresAutomaticallyOption: false,
                         NSInferMappingModelAutomaticallyOption: false]
    
    let store = try! coordinator.addPersistentStore(type: .sqlite, at: AppDelegate.current.storeURL, options: options)
    store.isReadOnly = true
    
    let context = NSManagedObjectContext(.privateQueue)
    context.persistentStoreCoordinator = coordinator
    
    let request = NSFetchRequest<NSManagedObject>(entityName: "Message")
    request.fetchLimit = 10
    request.predicate = NSPredicate(format: "lastMessageOf != NULL")
    
    let result = try! context.fetch(request)
    
    scope("Check KVC set relationshiop") {
      let lastMessage = result.first!
      let chat = (lastMessage as! Message).lastMessageOf!
      
      print(chat.lastMessage)
      lastMessage.setValue(nil, forKey: "lastMessageOf")
      print(chat.lastMessage)
    }
    
//    result?.forEach({ message in
//      if let messageId = message.value(forKey: "messageID") {
//        print(messageId)
//      }
//    })
    
  }
  @IBAction func clickInsertManualMigrationData(_ sender: Any) {
    insertManualMigrationTestData()
  }
  
  func insertManualMigrationTestData() {
//    try! insert(chatID: 1, messageCount: 100_000)
    try! insert(chatID: 2, messageCount: 10)
//    try! insert(chatID: 3, messageCount: 10)
  }
  
  private func insert(chatID: Int64, messageCount: Int) throws {
    let context = AppDelegate.current.persistentContainer.viewContext
    
    let chat = Chat(context: context)
    chat.name = "TestChat \(chatID)"
    chat.chatID = chatID
    
    var lastMessage: Message? = nil
    for msgid in messageCounter..<(messageCounter + UInt64(messageCount)) {
      let message = Message.init(context: context)
      message.messageID = Int64(msgid)
      message.content = Data()
      message.text = "\(messageCounter) - try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)try! String.init(contentsOf: textURL)"
      lastMessage = message
    }
    
    chat.lastMessage = lastMessage
    
    try context.save()
    context.reset()
  }
  
  @IBAction func clickStartManualMigration(_ sender: Any) {
    guard let oldModelURL = Bundle.main.url(forResource: "CoreDataTest", withExtension: "momd")?.appendingPathComponent("CoreDataTest.mom"),
          let oldModel = NSManagedObjectModel(contentsOf: oldModelURL)
    else { fatalError() }
    
    guard let newModelURL = Bundle.main.url(forResource: "CoreDataTest", withExtension: "momd")?.appendingPathComponent("CoreDataTest v2.mom"),
          let newModel = NSManagedObjectModel(contentsOf: newModelURL)
    else { fatalError() }
    
    let migrator = ManualMigrator(from: oldModel, to: newModel, sourceStoreURL: AppDelegate.current.storeURL, migrationVersion: 1)
    migrator.eventDelegate = self
    DispatchQueue.global().async {
      migrator.start()
    }
  }
  
  var notificationQueue: DispatchQueue { return .main }
  
  func didReceive(event: ManualMigrator.Event) {
    NSLog("receive event: \(event)")
  }
}

public func scope(_ name: String, action: () -> Void) {
  print("[ \(name) ]")
  action()
}
