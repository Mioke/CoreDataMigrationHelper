//
//  Message.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/1/21.
//

import Foundation
import GRDB

class _ZMessage: TableRecord {
  
  static var databaseTableName: String { "ZMESSAGE" }
  
  var chatID: Int64 = 0
  var content: Data = Data()
  var messageID: Int64 = 0
  var text: String?
  var options: Int64 = 0
  var timestamp: Int64?
  
  var _PK: Int64 = 0
  var _ENT: Int64 = 0
  var _OPT: Int64 = 0
  
  // Relationship
  var lastMessageOfKey: Int64?
  var lastMessageOf: _ZChat?
  
  enum Column: String, ColumnExpression {
    case _PK = "Z_PK"
    case _ENT = "Z_ENT"
    case _OPT = "Z_OPT"
    case chatID = "ZCHATID"
    case timestamp = "ZTIMESTAMP"
    case content = "ZCONTENT"
    case messageID = "ZMESSAGEID"
    case text = "ZTEXT"
    case options = "ZOPTIONS"
    case lastMessageOfKey = "ZLASTMESSAGEOF"
  }
  
  init() {
    
  }
  
  required init(row: GRDB.Row) throws {
    self._PK = row[Column._PK]
    self._ENT = row[Column._ENT]
    self._OPT = row[Column._OPT]
    self.chatID = row[Column.chatID]
    self.content = row[Column.content]
    self.messageID = row[Column.messageID]
    self.text = row[Column.text]
    self.timestamp = row[Column.timestamp]
    self.options = row[Column.options]
    self.lastMessageOfKey = row[Column.lastMessageOfKey]
  }
  
  func encode(to container: inout GRDB.PersistenceContainer) throws {
    container[Column.chatID] = chatID
    container[Column.content] = content
    container[Column.timestamp] = timestamp
    container[Column.messageID] = messageID
    container[Column.text] = text
    container[Column.options] = options
    container[Column.lastMessageOfKey] = lastMessageOfKey
    container[Column._ENT] = _ENT
    container[Column._OPT] = _OPT
    container[Column._PK] = _PK
  }
}

extension _ZMessage: SeaTalkDatabaseRecord {
  
  static var introducedVersion: SeaTalkDatabase.Version {
    .v1
  }
  static var deprecatedVersion: SeaTalkDatabase.Version? = nil
  
  static var migrateHanlder: [SeaTalkDatabase.Version : (GRDB.Database) throws -> Void] {
    [
      .v1: { db in
        try db.execute(sql: """
          CREATE TABLE IF NOT EXISTS ZMESSAGE ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZCHATID INTEGER, ZMESSAGEID INTEGER, ZOPTIONS INTEGER, ZTIMESTAMP INTEGER, ZLASTMESSAGEOF INTEGER, ZTEXT VARCHAR, ZCONTENT BLOB )
          """)
      }
    ]
  }
  
  static var coredataModelDisplayName: String {
    "Message"
  }
  
  static var relationships: [OpaqueRelationship] = [
    .init(relationship: lastMessageOfRelationship, inverse: _ZChat.lastMessageRelationship)
  ]
  
  static let lastMessageOfRelationship: RelationshipKind = .toOne(
    relationshipName: "lastMessageOf",
    keyPath: \_ZMessage.lastMessageOfKey,
    destination: \_ZMessage.lastMessageOf,
    deleteRule: .nullify)
  
}

