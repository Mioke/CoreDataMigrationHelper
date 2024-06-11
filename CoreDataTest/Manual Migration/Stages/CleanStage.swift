//
//  CleanStage.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/5/28.
//

import Foundation
import CoreData

class CleanStage: ManualStage {
  static var stageType: ManualMigrator.StageType { .clean }
  var eventReceiver: (any ManualMigratorEventReceiver)?
  
  let sourceURL: URL
  let temporaryURL: URL
  
  init(sourceURL: URL, temporaryURL: URL) {
    self.sourceURL = sourceURL
    self.temporaryURL = temporaryURL
  }
  
  func process() throws {
    
  }
  
  func fallback() {
    
  }
}
