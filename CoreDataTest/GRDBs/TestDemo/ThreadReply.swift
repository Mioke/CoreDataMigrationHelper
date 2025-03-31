//
//  ThreadReply.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/3/28.
//

import Foundation
import GRDB

class ZThreadReply: SeaTalkDatabaseRecord {
  static var introducedVersion: SeaTalkDatabase.Version = .v2
  
  static var deprecatedVersion: SeaTalkDatabase.Version? = nil
  
  static var migrateHanlder: [SeaTalkDatabase.Version : (GRDB.Database) throws -> Void] = [
    .v2: { db in
      try db.execute(literal: "CREATE TABLE ZTHREADREPLY ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZMESSAGEID INTEGER, ZROOTMESSAGEID INTEGER, ZROOTMESSAGE INTEGER )")
    }
  ]
  
  static var coredataModelDisplayName: String = "ZTHREADREPLY"
  
  static var relationships: [OpaqueRelationship] = []
  
  var _PK: Int64
  var _ENT: Int64
  var _OPT: Int64
  var messageID: Int64
  var rootMessageID: Int64
  
  enum Column: String, ColumnExpression {
    case _PK = "Z_PK"
    case _ENT = "Z_ENT"
    case _OPT = "Z_OPT"
    case messageID = "ZMESSAGEID"
    case threadRootMessageID = "ZROOTMESSAGEID"
  }
  
  required init(row: GRDB.Row) throws {
    _PK = row[Column._PK]
    _ENT = row[Column._ENT]
    _OPT = row[Column._OPT]
    messageID = row[Column.messageID]
    rootMessageID = row[Column.threadRootMessageID]
  }
  
  func encode(to container: inout GRDB.PersistenceContainer) throws {
    container[Column._PK] = _PK
    container[Column._ENT] = _ENT
    container[Column._OPT] = _OPT
    container[Column.messageID] = messageID
    container[Column.threadRootMessageID] = rootMessageID
  }
  
  
}
