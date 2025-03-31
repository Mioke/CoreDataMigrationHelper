//
//  EntityMeta.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/3/19.
//

import Foundation
import GRDB

struct _ENTMETA: TableRecord {
  static var databaseTableName: String { "Z_ENTMETA" }
  
  var _PK: Int64 = 1
  var _SCHEMA: Int64
  var _MAX: Int64
  
  enum Column: String, ColumnExpression {
    case _PK = "Z_PK"
    case _SCHEMA = "Z_SCHEMA"
    case _MAX = "Z_MAX"
  }
}

extension _ENTMETA: FetchableRecord {
  init(row: GRDB.Row) throws {
    _SCHEMA = row[Column._SCHEMA]
    _MAX = row[Column._MAX]
    _PK = row[Column._PK]
  }
}

extension _ENTMETA: PersistableRecord {
  func encode(to container: inout GRDB.PersistenceContainer) throws {
    container[Column._SCHEMA] = _SCHEMA
    container[Column._MAX] = _MAX
    container[Column._PK] = _PK
  }
}

extension _ENTMETA {
  static func createTableIfNeeded(in db: Database) throws {
    guard try db.tableExists(Self.databaseTableName) == false else { return }
    try db.create(table: Self.databaseTableName) { def in
      def.column(Column._PK.rawValue, .integer).primaryKey()
      def.column(Column._SCHEMA.rawValue, .integer).notNull()
      def.column(Column._MAX.rawValue, .integer).notNull()
    }
  }
  
  static func fetchOrCreate(in db: Database, version: Int) throws -> _ENTMETA {
    if let meta = try _ENTMETA.fetchOne(db) {
      return meta
    } else {
      let meta = _ENTMETA.init(_SCHEMA: Int64(version), _MAX: 0)
      try meta.insert(db)
      return meta
    }
  }
  
  static func updateMax(in db: Database, count: Int, version: Int) throws -> Range<Int> {
    var current = try fetchOrCreate(in: db, version: 0)
    let origin = Int(current._MAX)
    current._MAX += Int64(count)
    current._SCHEMA = Int64(version)
    try current.update(db, onConflict: .replace)
    return Int(origin + 1) ..< Int(origin + 1 + count)
  }
}
