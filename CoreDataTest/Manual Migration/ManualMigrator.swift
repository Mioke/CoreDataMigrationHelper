//
//  ManualMigrator.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/5/28.
//

import Foundation
import CoreData

public class ManualMigrator: ManualMigratorEventReceiver {
  
  let currentVersion: Int
  
  // @ThreadSafe
  public var state: State = .ready {
    didSet { receive(event: .migratorStateChange(prev: oldValue, current: state)) }
  }
  public weak var eventDelegate: ManualMigratorEventDelegate?
  
  var stages: [any ManualStage] = []
  var runningStage: ManualStage? {
    didSet { didSetRunningStage(newStage: runningStage, oldStage: oldValue) }
  }
  
  let sourceStoreURL: URL
  let oldModel: NSManagedObjectModel
  let newModel: NSManagedObjectModel
  let temporaryStoreURL: URL
  
  private var meta: NSManagedObjectContext {
    get throws {
      switch state {
      case .running(let meta): return meta
      default: throw ManualMigrator.Error.cannotCreateMeta
      }
    }
  }
  
  public private(set) var customizedEntities: [String: Any] = [:]
  
  public init(
    from oldModel: NSManagedObjectModel,
    to newModel: NSManagedObjectModel,
    sourceStoreURL: URL,
    migrationVersion: Int
  ) {
    self.currentVersion = migrationVersion
    self.sourceStoreURL = sourceStoreURL
    self.oldModel = oldModel
    self.newModel = newModel
    
    let fileName = sourceStoreURL.deletingPathExtension().lastPathComponent
    let ext = sourceStoreURL.pathExtension
    let temporaryFileName = "\(fileName)-temp.\(ext)"
    self.temporaryStoreURL = sourceStoreURL.deletingLastPathComponent().appendingPathComponent(temporaryFileName)
  }
  
  public func register(entity: String, process: (NSManagedObject, NSManagedObjectContext) -> Void) {}
  
  public func start() {
    guard case .ready = state else { fatalError() }
    
    do {
      let meta = try initilizeMetaContext()
      state = .running(meta: meta)
      try setupStages(with: meta)
      try recoverFromPreviousMeta(meta)
      try stages.sorted(by: { type(of: $0).stageType.rawValue < type(of: $1).stageType.rawValue })
        .forEach { stage in
          runningStage = stage
          try stage.process()
          runningStage = nil
        }
      state = .finished
    } catch {
      print(error)
      runningStage?.fallback()
      state = .failed(error)
    }
  }
  
  private func didSetRunningStage(newStage: ManualStage?, oldStage: ManualStage?) {
    guard let meta = try? self.meta else { return }
    do {
      try MigrateProgress.update(version: currentVersion, in: meta) { progress in
        if let runningStage = newStage {
          progress.processingStage = type(of: runningStage).stageType
        } else {
          // only set to nil when finishing one stage.
          progress.processingStage = nil
          if let oldStage = oldStage {
            progress.finishedStage = type(of: oldStage).stageType
          }
        }
      }
    } catch {
      print("Setting running stage failed in meta context.", error)
    }
  }
  
  private func recoverFromPreviousMeta(_ meta: NSManagedObjectContext) throws {
    let progress = try MigrateProgress.fetchOrCreate(with: currentVersion, in: meta)
    
    if let finishedStage = progress.finishedStage,
       let lastStage = stages.max(by: { type(of: $0).stageType.rawValue < type(of: $1).stageType.rawValue }),
       finishedStage == type(of: lastStage).stageType {
      throw ManualMigrator.Error.versionCompleted
    }
    
    if let previousProcessing = progress.processingStage,
       progress.isStageInterrupted(previousProcessing),
       let theStage = stages.first(where: { type(of: $0).stageType == previousProcessing }) {
      theStage.fallback()
    }
  }
  
  func initilizeMetaContext() throws -> NSManagedObjectContext {
    let bundle = Bundle(for: type(of: self))
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
      .first?
      .appendingPathComponent("migration_meta.sqlite")
    
    guard let modelURL = bundle.url(forResource: "MigrationMeta", withExtension: "momd"),
          let model = NSManagedObjectModel(contentsOf: modelURL),
          let url = url
    else { fatalError() }
    
    return try MigrateUtils.createContext(using: model, at: url, readOnly: false)
  }
  
  private func setupStages(with meta: NSManagedObjectContext) throws {
    let reader = try RawCoreDataReader(storeURL: sourceStoreURL, model: oldModel)
    reader.fetchLimit = 10000
    stages = [
      CreateTemporaryStoreStage(
        model: newModel,
        targetURL: temporaryStoreURL),
      DefaultMigrationStage(
        sourceModel: oldModel,
        targetModel: newModel,
        ignoreEntities: Array(customizedEntities.keys),
        sourceReader: reader,
        targetURL: temporaryStoreURL, 
        meta: meta),
      PostCheckStage(targetURL: temporaryStoreURL, coreDataModel: newModel),
      CleanStage(sourceURL: sourceStoreURL, temporaryURL: temporaryStoreURL),
    ]
    stages.forEach { $0.eventReceiver = self }
  }
  
  func receive(event: Event) {
    eventDelegate?.notificationQueue.async { [weak self] in
      self?.eventDelegate?.didReceive(event: event)
    }
  }
  
}

// MARK: - Internal Stages

extension ManualMigrator {
  
  enum StageType: Int {
    case createTemporaryStore = 1
    case defaultMigration
    case customMigration
    case postCheck
    case clean
  }
  
}

protocol ManualMigratorEventReceiver: AnyObject {
  func receive(event: ManualMigrator.Event)
}

protocol ManualStage: AnyObject {
  static var stageType: ManualMigrator.StageType { get }
  var eventReceiver: ManualMigratorEventReceiver? { get set }
  func process() throws
  func fallback()
}

extension ManualStage {
  var eventReceiver: ManualMigratorEventReceiver? { return nil }
}

public class RawCoreDataReader {
  
  public var context: NSManagedObjectContext
  public var fetchLimit: Int = 10000
  
  public init(storeURL: URL, model: NSManagedObjectModel) throws {
    guard FileManager.default.fileExists(atPath: storeURL.path) else { throw ManualMigrator.Error.sourceStoreNotExists }
    context = try MigrateUtils.createContext(using: model, at: storeURL)
  }
  
  public func fetchAllEntities(
    entityName: String,
    from offset: Int = 0,
    batchHandler: ((objects: [NSManagedObject], nextOffset: Int, hasFinished: Bool)) throws -> Void)
  throws {
    var isFinal = false
    var currentOffset: Int = offset
    let batchSize = fetchLimit
    
    while !isFinal {
      try autoreleasepool {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchLimit = batchSize
        request.fetchOffset = currentOffset
        let results = try context.fetch(request)
        currentOffset += batchSize
        isFinal = results.count < batchSize
        try batchHandler((results, currentOffset, isFinal))
      }
    }
  }
}

public class MigrateUtils {
  public static func createContext(
    using model: NSManagedObjectModel,
    at url: URL,
    readOnly: Bool = true)
  throws -> NSManagedObjectContext {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    let options = [NSMigratePersistentStoresAutomaticallyOption: false,
                         NSInferMappingModelAutomaticallyOption: false]
    
    let store = try coordinator.addPersistentStore(type: .sqlite, at: url, options: options)
    store.isReadOnly = readOnly
    
    let context = NSManagedObjectContext(.privateQueue)
    context.persistentStoreCoordinator = coordinator
    
    return context
  }
}
