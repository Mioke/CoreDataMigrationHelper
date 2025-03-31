//
//  CoreDataDatabaseManagable.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/2/7.
//

import Foundation
import GRDB
import CoreData

public struct FetchRequest {
  var prefetchingRelationships: [String]
}

public protocol SeaTalkDatabaseRecord: CoreDataDatabaseManagable {
  static var introducedVersion: SeaTalkDatabase.Version { get }
  static var deprecatedVersion: SeaTalkDatabase.Version? { get }
  static var migrateHanlder: [SeaTalkDatabase.Version: (GRDB.Database) throws -> Void] { get }
}

public protocol CoreDataDatabaseManagable: PersistableRecord, AnyObject, FetchableRecord {
  
  static var coredataModelDisplayName: String { get }
  
  static var relationships: [OpaqueRelationship] { get }
  
  /// CoreData reserved - Primary key
  var _PK: Int64 { get set }
  /// CoreData reserved - The primary key value in the `_PRIMARYKEY` table.
  var _ENT: Int64 { get set }
  /// CoreData reserved - Options
  var _OPT: Int64 { get set }
}

/// :CRUD:
public extension SeaTalkDatabaseRecord {
  
  func populateRelationships(in db: Database) throws {
    for relationship in Self.relationships {
      try relationship.reader(db, self)
    }
  }
  
  func create(in db: Database) throws {
    try db.inTransaction {
      let result = try _PRIMARYKEY.bumpPrimaryKey(in: db, coreDataModelName: Self.coredataModelDisplayName)
      _PK = result.pk
      _ENT = result.ent
      try _updateRelationships(in: db)
      try insert(db, onConflict: .fail)
      return .commit
    }
  }
  
  func update(in db: Database, onConflict: Database.ConflictResolution? = nil) throws {
    try db.inTransaction {
      try _updateRelationships(in: db)
      try update(db, onConflict: onConflict)
      return .commit
    }
  }
  
  func delete(in db: Database) throws {
    try db.inTransaction {
      try _deleteRelationships(in: db)
      try delete(db)
      return .commit
    }
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
