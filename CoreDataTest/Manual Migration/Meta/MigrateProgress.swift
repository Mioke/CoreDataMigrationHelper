//
//  MigrateProgress.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/6/5.
//

import Foundation
import CoreData

extension MigrateProgress {
  
  var finishedStage: ManualMigrator.StageType? {
    get {
      return .init(rawValue: Int(finishedStageValue))
    }
    set {
      finishedStageValue = Int16(newValue?.rawValue ?? 0)
    }
  }
  
  var processingStage: ManualMigrator.StageType? {
    get {
      return .init(rawValue: Int(processingStageValue))
    }
    set {
      processingStageValue = Int16(newValue?.rawValue ?? 0)
    }
  }
  
  func isStageInterrupted(_ stage: ManualMigrator.StageType) -> Bool {
    guard let finishedStage = self.finishedStage,
          let processingStage = self.processingStage,
          processingStage == stage
    else {
      return false
    }
    return finishedStage == processingStage
  }
  
  static func fetchOrCreate(with version: Int, in context: NSManagedObjectContext) throws -> MigrateProgress {
    if let progress = try self.fetch(with: version, in: context) {
      return progress
    } else {
      let progress = MigrateProgress(context: context)
      progress.version = Int16(version)
      try context.save()
      return progress
    }
  }
  
  static func fetch(with version: Int, in context: NSManagedObjectContext) throws -> MigrateProgress? {
    let request = MigrateProgress.fetchRequest()
    request.predicate = NSPredicate(format: "version == %@", argumentArray: [version])
    return try context.fetch(request).first
  }
  
  static func update(
    version: Int,
    in context: NSManagedObjectContext,
    updateOperation: (MigrateProgress) -> Void)
  throws {
    try context.performAndWait {
      guard let exist = try fetch(with: version, in: context) else { return }
      updateOperation(exist)
      try context.save()
    }
    
  }
}

