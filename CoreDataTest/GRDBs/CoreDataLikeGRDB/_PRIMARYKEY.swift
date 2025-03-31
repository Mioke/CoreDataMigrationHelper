//
//  _PRIMARYKEY.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/2/7.
//

import Foundation
import GRDB

struct _PRIMARYKEY: TableRecord {
  static var databaseTableName: String { "Z_PRIMARYKEY" }
  
  var _ENT: Int64
  var _NAME: String
  var _SUPER: Int64 = 0
  var _MAX: Int64
  
  enum Column: String, ColumnExpression {
    case _ENT = "Z_ENT"
    case _NAME = "Z_NAME"
    case _SUPER = "Z_SUPER"
    case _MAX = "Z_MAX"
  }
}

extension _PRIMARYKEY: FetchableRecord {
  init(row: GRDB.Row) throws {
    _ENT = row[Column._ENT]
    _NAME = row[Column._NAME]
    _SUPER = row[Column._SUPER]
    _MAX = row[Column._MAX]
  }
}

extension _PRIMARYKEY: PersistableRecord {
  func encode(to container: inout GRDB.PersistenceContainer) throws {
    container[Column._ENT] = _ENT
    container[Column._NAME] = _NAME
    container[Column._SUPER] = _SUPER
    container[Column._MAX] = _MAX
  }
}

extension _PRIMARYKEY {
  static func bumpPrimaryKey(in db: Database, coreDataModelName: String, count: Int64 = 1) throws -> (pk: Int64, ent: Int64) {
    if var existing = try filter(Column._NAME == coreDataModelName).fetchOne(db) {
      let next = existing._MAX + count
      existing._MAX = next
      try existing.update(db)
      return (next, existing._ENT)
    } else {
      let ent = try nextENT(in: db)
      let key = _PRIMARYKEY(_ENT: ent, _NAME: coreDataModelName, _MAX: 1)
      try key.insert(db, onConflict: .fail)
      return (key._MAX, key._ENT)
    }
  }
  
  static func ENT(of coreDataModelName: String, in db: Database) throws -> Int64? {
    if let existing = try filter(Column._NAME == coreDataModelName).fetchOne(db) {
      return existing._ENT
    }
    return nil
  }
  
  static func nextENT(in db: Database) throws -> Int64 {
    if let max = try Self.select(max(Column._ENT)).fetchOne(db) {
      return max._ENT + 1
    } else {
      return 1
    }
  }
  
  static func creation(in db: Database) throws {
    guard try db.tableExists(Self.databaseTableName) == false else { return }
    try db.execute(sql: """
      CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER PRIMARY KEY, Z_NAME VARCHAR, Z_SUPER INTEGER, Z_MAX INTEGER)
      """)
  }
}
