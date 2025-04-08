//
//  ThreadReply.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/3/28.
//

import Foundation
import GRDB

extension ZThreadReply {
  static let rootMessageRelationship: RelationshipKind<ZThreadReply, _ZMessage> = .toOne(
    relationshipName: "rootMessage",
    keyPath: \.rootMessageValue,
    destination: \.rootMessage,
    deleteRule: .nullify)
}

class ZThreadReply: NSObject, SeaTalkDatabaseRecord {
  
  static var introducedVersion: SeaTalkDatabase.Version = .v2
  
  static var migrateHanlder: [SeaTalkDatabase.Version : (GRDB.Database) throws -> Void] = [
    .v2: { db in
      try db.execute(literal: "CREATE TABLE ZTHREADREPLY ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZMESSAGEID INTEGER, ZROOTMESSAGEID INTEGER, ZROOTMESSAGE INTEGER )")
    }
  ]
  
  static var databaseTableName: String = "ZTHREADREPLY"
  static var coredataModelDisplayName: String = "ThreadReply"
  
  static var relationships: [OpaqueRelationship] = [
    .init(relationship: ZThreadReply.rootMessageRelationship, inverse: _ZMessage.repliesRelationship)
  ]
  
  var _PK: Int64 = 0
  var _ENT: Int64 = 0
  var _OPT: Int64 = 0
  var messageID: Int64 = 0
  var rootMessageID: Int64 = 0
  
  var rootMessageValue: Int64?
  var rootMessage: _ZMessage?
  
  override init() { }
  
  enum Column: String, ColumnExpression {
    case _PK = "Z_PK"
    case _ENT = "Z_ENT"
    case _OPT = "Z_OPT"
    case messageID = "ZMESSAGEID"
    case threadRootMessageID = "ZROOTMESSAGEID"
    case rootMessageValue = "ZROOTMESSAGE"
  }
  
  required init(row: GRDB.Row) throws {
    _PK = row[Column._PK]
    _ENT = row[Column._ENT]
    _OPT = row[Column._OPT]
    messageID = row[Column.messageID]
    rootMessageID = row[Column.threadRootMessageID]
    rootMessageValue = row[Column.rootMessageValue]
  }
  
  func encode(to container: inout GRDB.PersistenceContainer) throws {
    container[Column._PK] = _PK
    container[Column._ENT] = _ENT
    container[Column._OPT] = _OPT
    container[Column.messageID] = messageID
    container[Column.threadRootMessageID] = rootMessageID
    container[Column.rootMessageValue] = rootMessageValue
  }
  
  
}
