//
//  Chat.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/1/22.
//

import Foundation
import GRDB

final class _ZChat: TableRecord {
  static var databaseTableName: String { "ZCHAT" }
  
  var chatID: Int64 = 0
  var name: String = ""
  
  var _PK: Int64 = 0
  var _ENT: Int64 = 0
  var _OPT: Int64 = 0
  
  // Relationship
  var lastMesssageKey: Int64?
  var lastMessaage: _ZMessage?
  
//  var usersKeys: [Int64]
//  var
  
  enum Column: String, ColumnExpression {
    case _PK = "Z_PK"
    case _ENT = "Z_ENT"
    case _OPT = "Z_OPT"
    case chatID = "ZCHATID"
    case name = "ZNAME"
    case lastMesssageKey = "ZLASTMESSAGE"
  }
  
  required init(row: GRDB.Row) throws {
    chatID = row[Column.chatID]
    name = row[Column.name]
    lastMesssageKey = row[Column.lastMesssageKey]
    _ENT = row[Column._ENT]
    _OPT = row[Column._OPT]
    _PK = row[Column._PK]
  }
  
  func encode(to container: inout PersistenceContainer) throws {
    container[Column.chatID] = chatID
    container[Column.name] = name
    container[Column.lastMesssageKey] = lastMesssageKey
    container[Column._ENT] = _ENT
    container[Column._OPT] = _OPT
    container[Column._PK] = _PK
  }
}

extension _ZChat: SeaTalkDatabaseRecord {
  static var introducedVersion: SeaTalkDatabase.Version {
    .v1
  }
  static var deprecatedVersion: SeaTalkDatabase.Version? = nil
  
  static var migrateHanlder: [SeaTalkDatabase.Version : (GRDB.Database) throws -> Void] {
    [
      .v1: { db in
        try db.execute(sql: """
          CREATE TABLE ZCHAT ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZCHATID INTEGER, ZLASTMESSAGE INTEGER, ZNAME VARCHAR )
          """)
      }
    ]
  }
  
  static var coredataModelDisplayName: String {
    "Chat"
  }
  
  static let lastMessageRelationship: RelationshipKind = .toOne(
    relationshipName: "lastMessage",
    keyPath: \_ZChat.lastMesssageKey,
    destination: \_ZChat.lastMessaage,
    deleteRule: .nullify
  )
  
  static var relationships: [OpaqueRelationship] {
    [
      .init(relationship: Self.lastMessageRelationship, inverse: _ZMessage.lastMessageOfRelationship)
    ]
  }
}
