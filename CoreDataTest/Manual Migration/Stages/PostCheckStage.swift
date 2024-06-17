//
//  PostCheckStage.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/5/28.
//

import Foundation
import CoreData

class PostCheckStage: ManualStage {
  static var stageType: ManualMigrator.StageType { .postCheck }
  var eventReceiver: (any ManualMigratorEventReceiver)?
  
  let targetURL: URL
  let coreDataModel: NSManagedObjectModel
  
  init(targetURL: URL, coreDataModel: NSManagedObjectModel) {
    self.targetURL = targetURL
    self.coreDataModel = coreDataModel
  }
  
  func process() throws {
    _ = try MigrateUtils.createContext(using: coreDataModel, at: targetURL)
  }
  
  func fallback() {
    // nop
  }
}
