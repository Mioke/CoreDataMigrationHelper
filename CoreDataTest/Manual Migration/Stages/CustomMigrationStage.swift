//
//  CustomMigrationStage.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/5/28.
//

import Foundation
import CoreData

class CustomMigrationStage: ManualStage {
  
  static var stageType: ManualMigrator.StageType { .customMigration }
  var eventReceiver: (any ManualMigratorEventReceiver)?
  
  let sourceReader: RawCoreDataReader
  let targetContext: NSManagedObjectContext
  let insertProcess: (NSManagedObject, NSManagedObjectContext) -> Void
  
  /// Because there ignores the objects, so the relationships are stored in `DefaultMigrationStage`. Here we need to
  /// capture the default stage to get relationship map
  let defultStage: DefaultMigrationStage
  
  init(sourceReader: RawCoreDataReader,
       targetContext: NSManagedObjectContext,
       defultStage: DefaultMigrationStage,
       insertProcess: @escaping (NSManagedObject, NSManagedObjectContext) -> Void) {
    self.sourceReader = sourceReader
    self.targetContext = targetContext
    self.defultStage = defultStage
    self.insertProcess = insertProcess
  }
  
  func process() throws {
  }
  func fallback() {
    
  }
}
