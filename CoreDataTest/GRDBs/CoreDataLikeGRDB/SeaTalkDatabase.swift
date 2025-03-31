//
//  SeaTalkDataBase.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/3/4.
//

import Foundation
import GRDB
import CoreData

class CoreDataMigrator {
  
  var grdbMigrator: DatabaseMigrator = .init().disablingDeferredForeignKeyChecks()
  weak var database: SeaTalkDatabase?
  var shouldSkipGRDBFirstVersion: Bool = false
  
  init(database: SeaTalkDatabase) {
    self.database = database
    registerMigrations()
  }
  
  private func registerMigrations() {
    guard let seatalkDB = self.database else {
      return
    }
    
    guard let containedVersions = seatalkDB.containedVersions else { return }
    let initiateVersion = containedVersions.initiate
    
    grdbMigrator.registerMigration(initiateVersion.grdbVersion()) { [weak self] db in
      guard let self else { return }
      try _ENTMETA.createTableIfNeeded(in: db)
      // if using an existed coredata's database, we don't need the whole create process.
      if shouldSkipGRDBFirstVersion {
        // if skip, only update current entity meta state.
        try _updateEntityMaxUsingCurrentState(in: db, version: initiateVersion)
        return
      }
      
      // create tables and indicies as primary version
      let primaryModels = seatalkDB.models.filter {
        return $0.introducedVersion == initiateVersion
      }
      
      try primaryModels.forEach {
        try $0.migrateHanlder[initiateVersion]?(db)
      }
      
      // create _PRIMARYKEY table
      try _PRIMARYKEY.creation(in: db)
      try _maintainsPrimaryKeyTable(in: db, initialVersion: initiateVersion)
    }
    
    containedVersions.later
      .sorted(by: <)
      .forEach { version in
        // handle each version, assending.
        grdbMigrator.registerMigration(version.grdbVersion()) { [weak self] db in
          guard let self else { return }
          
          try seatalkDB.models
          // only filter the model introduced before or equals to this version.
            .filter { $0.introducedVersion <= version }
            .forEach { model in
              if let handler = model.migrateHanlder[version] {
                try handler(db)
              }
            }
          
          try _maintainsPrimaryKeyTable(in: db, initialVersion: version)
        }
      }
  }
  
  func needMigration(database: DatabasePool) throws -> Bool {
    try database.read { try !grdbMigrator.hasCompletedMigrations($0) }
  }
  
  func migrate(database: DatabaseWriter) throws {
    try grdbMigrator.migrate(database)
  }
  
  private func _maintainsPrimaryKeyTable(in database: Database, initialVersion: SeaTalkDatabase.Version) throws {
    guard let models = self.database?.models else { return }
    let currentVersionModels = models.filter { $0.introducedVersion == initialVersion }
    if currentVersionModels.isEmpty { return }
    
    let range = try _ENTMETA.updateMax(
      in: database,
      count: currentVersionModels.count,
      version: initialVersion.rawValue)
    
    var index = 0
    for ent in range {
      let model = currentVersionModels[index]
      let record = _PRIMARYKEY(_ENT: Int64(ent), _NAME: model.coredataModelDisplayName, _SUPER: 0, _MAX: 0)
      try record.insert(database, onConflict: .fail)
      index += 1
    }
  }
  
  private func _insertPrimaryKeyTable<T: SeaTalkDatabaseRecord>(of model: T.Type, in database: Database) throws {
    let ent = try _PRIMARYKEY.nextENT(in: database)
    let record = _PRIMARYKEY(_ENT: ent, _NAME: model.coredataModelDisplayName, _SUPER: 0, _MAX: 0)
    try record.insert(database, onConflict: .fail)
  }
  
  private func _updateEntityMaxUsingCurrentState(in database: Database, version: SeaTalkDatabase.Version) throws {
    let maxEnt = try _PRIMARYKEY.nextENT(in: database) - 1
    var meta = try _ENTMETA.fetchOrCreate(in: database, version: version.rawValue)
    meta._MAX = maxEnt
    meta._SCHEMA = Int64(version.rawValue)
    try meta.update(database)
  }
}

public struct TableMeta {
  public var name: String
  public var ent: Int
}

public class SeaTalkDatabase {
  
  typealias ENT = Int
  
  static let defaults = UserDefaults(suiteName: "com.seagroup.seatalk-database")!
  
  public var url: URL
  public var configuration: Configuration = .init()
  // lazify later
  public private(set) var pool: DatabasePool
  lazy var migrator: CoreDataMigrator = .init(database: self)
  
  var coreDataModelName: String?
  var models: [SeaTalkDatabaseRecord.Type] = []
  var containedVersions: (initiate: Version, later: Set<Version>)?
  
  var entityIndex: BidirectionDictionary<ENT, String> = .init()
  
  public enum State: Int {
    case newlyInitialized = 1
    case beforeHandOverFromCoreData
    case afterHandOverFromCoreData
  }
  
  public enum Exception: Swift.Error {
    case error
    case modelRegisteringUnknownVersion
    case unregistered
  }
  
  public var state: State {
    didSet {
      SeaTalkDatabase.defaults.set(state.rawValue, forKey: databaseStateKey(of: url))
    }
  }
  
  public init(url: URL, originalCoreDataModel: String? = nil, register block: (SeaTalkDatabase) throws -> Void) throws {
    self.url = url
    self.coreDataModelName = originalCoreDataModel
    
    configuration.journalMode = .wal
    configuration.automaticMemoryManagement = false
    
    let storedStateValue = SeaTalkDatabase.defaults.integer(forKey: databaseStateKey(of: url))
    
    if storedStateValue != 0 {
      if let storedState = State(rawValue: storedStateValue) {
        state = storedState
      } else {
        // reset userdefaults
        SeaTalkDatabase.defaults.set(nil, forKey: databaseStateKey(of: url))
        state = .newlyInitialized
      }
    } else {
      if originalCoreDataModel != nil {
        state = FileManager.default.fileExists(atPath: url.path) ? .beforeHandOverFromCoreData : .newlyInitialized
      } else {
        state = .newlyInitialized
      }
      // set manually, didSet won't be called when initiating
      SeaTalkDatabase.defaults.set(state.rawValue, forKey: databaseStateKey(of: url))
    }
    // create database file if not exists.
    self.pool = try DatabasePool(path: url.path, configuration: configuration)
    try block(self)
    try checkMigrations()
    try loadEntityMeta()
  }
  
  private func handleMigrationFromCoreDataIfNeeded() throws {
    guard let coreDataModelName, FileManager.default.fileExists(atPath: url.path) else { return }
    
    let container = NSPersistentContainer(name: coreDataModelName)
    container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
    container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true
    container.persistentStoreDescriptions.first?.url = self.url
    
    var error: Error?
    container.loadPersistentStores { descriptor, err in
      error = err
    }
    
    if let error { throw error }
    
    migrator.shouldSkipGRDBFirstVersion = true
    try migrator.migrate(database: pool)
    
    state = .afterHandOverFromCoreData
  }
  
  private func checkMigrations() throws {
    switch state {
    case .newlyInitialized:
      migrator.shouldSkipGRDBFirstVersion = false
    case .afterHandOverFromCoreData:
      migrator.shouldSkipGRDBFirstVersion = true
    case .beforeHandOverFromCoreData:
      try handleMigrationFromCoreDataIfNeeded()
      return
    }
    
    if try migrator.needMigration(database: pool) {
      try migrator.migrate(database: pool)
    } else {
      print("Migraion no need")
    }
  }
  
  private func loadEntityMeta() throws {
    
  }
  
  public func register(primaryVersion: Version, laterVersions: Set<Version>) throws {
    if let next = laterVersions.sorted(by: <).first, primaryVersion >= next {
      throw Exception.error
    }
    containedVersions = (primaryVersion, laterVersions)
  }
  
  public func register<T: SeaTalkDatabaseRecord>(_ type: T.Type) throws {
    guard let containedVersions else {
      fatalError("Must call register(primaryVersion:laterVersions:) before registering CoreDataModel.")
    }
    let registedVersions = Set(containedVersions.later + [containedVersions.initiate])
    if Set(type.migrateHanlder.keys).subtracting(registedVersions).isEmpty == false {
      throw Exception.modelRegisteringUnknownVersion
    }
    models.append(type)
  }
}


private func databaseStateKey(of url: URL) -> String {
  var path = url.path
  path.trimPrefix(NSHomeDirectory())
  return "isGRDBTookOver-\(path)"
}

extension SeaTalkDatabase {
  
  public struct Version: RawRepresentable, Comparable, Hashable {
    
    public var rawValue: Int
    
    public init(rawValue: RawValue) {
      self.rawValue = rawValue
    }
    
    public static func < (lhs: SeaTalkDatabase.Version, rhs: SeaTalkDatabase.Version) -> Bool {
      return lhs.rawValue < rhs.rawValue
    }
    
    public func grdbVersion() -> String {
      "v\(rawValue)"
    }
  }
  
  var currentVersion: Version {
    get throws {
      guard let registered = containedVersions else { throw Exception.unregistered }
      
      if registered.later.isEmpty {
        return registered.initiate
      } else {
        return registered.later.sorted(by: >).first!
      }
    }
  }
}

struct WeakObject<T: AnyObject> {
  weak var value: T?
  
  init(_ value: T) {
    self.value = value
  }
}
