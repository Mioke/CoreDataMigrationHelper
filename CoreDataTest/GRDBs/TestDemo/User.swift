//
//  User.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/2/8.
//

import Foundation
import GRDB

class _ZUser: SeaTalkDatabaseRecord {
  static var introducedVersion: SeaTalkDatabase.Version = .v1
  static var deprecatedVersion: SeaTalkDatabase.Version? = nil
  
  static var migrateHanlder: [SeaTalkDatabase.Version : (GRDB.Database) throws -> Void] = [
    .v1: { db in
      try db.execute(sql: """
          CREATE TABLE ZUSER ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZUID INTEGER, ZNAME VARCHAR )
          """)
    }
  ]
  
  static var coredataModelDisplayName: String  = "User"
  static var relationships: [OpaqueRelationship] = []
  
  var name: String = ""
  var uid: Int64 = 0
  
  var _PK: Int64 = 0
  var _ENT: Int64 = 0
  var _OPT: Int64 = 0
  
  enum Column: String, ColumnExpression {
    case name = "ZNAME"
    case uid = "ZUID"
    case _PK = "Z_PK"
    case _ENT = "Z_ENT"
    case _OPT = "Z_OPT"
  }
  
  required init(row: Row) throws {
    name = row[Column.name]
    _PK = row[Column._PK]
    _ENT = row[Column._ENT]
    _OPT = row[Column._OPT]
    uid = row[Column.uid]
  }
  
  func encode(to container: inout PersistenceContainer) throws {
    container[Column.name] = name
    container[Column.uid] = uid
    container[Column._PK] = _PK
    container[Column._ENT] = _ENT
    container[Column._OPT] = _OPT
  }
}
