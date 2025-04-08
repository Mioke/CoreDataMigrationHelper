//
//  CoreDataDatabaseManagable.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/2/7.
//

import Foundation
import GRDB
import CoreData

/// SeaTalkDatabaseRecord is kind of like NSManagedObject, but it has some differences:
/// + Contains informations like .xcdatamodeld.
/// + Including migrations, including table creation and innovations.
/// - Not live object, may contains outdated value.
public protocol SeaTalkDatabaseRecord: CoreDataDatabaseManagable, NSObject {
  static var introducedVersion: SeaTalkDatabase.Version { get }
  static var migrateHanlder: [SeaTalkDatabase.Version: (GRDB.Database) throws -> Void] { get }
}

public protocol CoreDataDatabaseManagable: PersistableRecord, AnyObject, FetchableRecord {
  
  static var coredataModelDisplayName: String { get }
  
  static var relationships: [OpaqueRelationship] { get }
  
  /// CoreData reserved - Primary key
  var _PK: Int64 { get set }
  /// CoreData reserved - The primary key value in the `_PRIMARYKEY` table, to mark the entity's id.
  var _ENT: Int64 { get set }
  /// CoreData reserved - seems to be used in `Optimistic Locking`, for now we don't implement database locking
  /// ourselves, reserve this column for future design option.
  var _OPT: Int64 { get set }
}

/// :CRUD:
public extension SeaTalkDatabaseRecord {
  
  // TODO: - temporary primary key
  @available(*, unavailable)
  init(context: SeaTalkDatabase) {
    self.init()
    _PK = -1
  }
  
  func populateRelationships(in db: Database, relationships: Set<String>? = nil) throws {
    // TODO: is read-only neccesary?
    try db.readOnly {
      for relationship in Self.relationships {
        if let relationships, relationships.contains(relationship.name) {
          try relationship.reader(db, self)
        }
      }
    }
  }
  
  func create(in db: Database, context: SeaTalkDatabase) throws {
    try insertPrepare(in: context)
    try db.inSavepoint {
      let result = try _PRIMARYKEY.bumpPrimaryKey(in: db, ent: _ENT)
      _PK = result.pk
      try _updateRelationships(in: db)
      try insert(db, onConflict: .fail)
      return .commit
    }
  }
  
  func created(in db: Database, context: SeaTalkDatabase) throws -> Self {
    try insertPrepare(in: context)
    var inserted: Self? = nil
    try db.inSavepoint {
      let result = try _PRIMARYKEY.bumpPrimaryKey(in: db, ent: _ENT)
      _PK = result.pk
      try _updateRelationships(in: db)
      // NOTE: not fetch, check if it is working for default columns.
      inserted = try self.inserted(db, onConflict: .fail)
      return .commit
    }
    return inserted!
  }
  
  private func insertPrepare(in db: SeaTalkDatabase) throws {
    guard let ent = db.entityIndex.key(forValue: Self.coredataModelDisplayName) else {
      throw SeaTalkDatabase.Exception.entityNotFound(ENT: nil, name: Self.coredataModelDisplayName)
    }
    _ENT = Int64(ent)
  }
  
  func update(in db: Database, onConflict: Database.ConflictResolution? = nil) throws {
    try db.inSavepoint {
      try _updateRelationships(in: db)
      try update(db, onConflict: onConflict)
      return .commit
    }
  }
  
  // TODO: - add when needed.
//  func updateAndFetch() { }
  
  func delete(in db: Database) throws {
    try db.inSavepoint {
      try _deleteRelationships(in: db)
      try delete(db)
      return .commit
    }
  }
  
  
}


public struct FetchRequest<T: SeaTalkDatabaseRecord> {
  public var prefetchingRelationships: Set<String> = []
  public private(set) var prediction: QueryInterfaceRequest<T>
  
  public func fetchOne(_ db: Database) throws -> T? {
    guard let value = try prediction.fetchOne(db) else {
      return nil
    }
    if !prefetchingRelationships.isEmpty {
      try value.populateRelationships(in: db, relationships: prefetchingRelationships)
    }
    return value
  }
  
  public func fetchall(_ db: Database) throws -> [T] {
    var result = try prediction.fetchAll(db)
    if !prefetchingRelationships.isEmpty {
      result = try result.map({ try $0.populateRelationships(in: db, relationships: prefetchingRelationships); return $0 })
    }
    return result
  }
  
  public func fetchCount(_ db: Database) throws -> Int {
    try prediction.fetchCount(db)
  }
}


// MARK: - Tools

extension SeaTalkDatabaseRecord {
  
  func _updateRelationships(in db: Database) throws {
    for relationship in Self.relationships {
      try relationship.updater(db, self)
    }
  }
  
  func _deleteRelationships(in db: Database) throws {
    for relationship in Self.relationships {
      try relationship.deletion(db, self)
    }
  }
  

}
