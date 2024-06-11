//
//  CreateTemporaryStoreStage.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/5/28.
//

import Foundation
import CoreData

class CreateTemporaryStoreStage: ManualStage {
  
  static var stageType: ManualMigrator.StageType { .createTemporaryStore }
  var eventReceiver: (any ManualMigratorEventReceiver)?
  
  let model: NSManagedObjectModel
  let targetURL: URL
  
  init(model: NSManagedObjectModel, targetURL: URL) {
    self.model = model
    self.targetURL = targetURL
  }
  
  func process() throws {
    // TODO: - to check disk space is sufficient
    
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    let options = [NSMigratePersistentStoresAutomaticallyOption: false,
                         NSInferMappingModelAutomaticallyOption: false]
    _ = try coordinator.addPersistentStore(type: .sqlite, at: targetURL, options: options)
  }
  
  func fallback() {
    try? FileManager.default.removeItem(at: targetURL)
  }
}
