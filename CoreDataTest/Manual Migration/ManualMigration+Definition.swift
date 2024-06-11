//
//  ManualMigration+Definition.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/6/5.
//

import Foundation
import CoreData

public protocol ManualMigratorEventDelegate: AnyObject {
  var notificationQueue: DispatchQueue { get }
  func didReceive(event: ManualMigrator.Event)
}

extension ManualMigrator {
  
  public enum State {
    case ready
    case running(meta: NSManagedObjectContext)
    case finished
    case failed(Swift.Error)
    
    var isRunning: Bool {
      if case .running = self {
        return true
      } else {
        return false
      }
    }
    
    var isOver: Bool {
      switch self {
      case .finished, .failed(_): return true
      default: return false
      }
    }
  }
  
  public enum Error: Swift.Error {
    case sourceStoreNotExists
    case cannotCreateMeta
    case versionCompleted
    case fetchError
  }
  
  public enum Event {
    case migratorStateChange(prev: ManualMigrator.State, current: ManualMigrator.State)
    case batchInserted(String, Int)
  }
}
