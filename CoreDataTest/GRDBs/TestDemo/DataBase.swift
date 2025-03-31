//
//  DataBase.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/2/21.
//

import Foundation
import GRDB

extension SeaTalkDatabase.Version {
  public static let v1: SeaTalkDatabase.Version = .init(rawValue: 1)
  public static let v2: SeaTalkDatabase.Version = .init(rawValue: 2)
}

class DemoStore {
  
  let database: SeaTalkDatabase
  var pool: DatabasePool { database.pool }
  
  init() throws {
    let url = AppDelegate.current.storeURL.deletingLastPathComponent().appending(path: "CoreDataTest_v2.sqlite")
    self.database = try .init(
      url: url,
      originalCoreDataModel: "CoreDataTest",
      register: { database in
        try database.register(primaryVersion: .v1, laterVersions: [.v2])
        try database.register(_ZMessage.self)
        try database.register(_ZChat.self)
        try database.register(_ZUser.self)
        try database.register(ZThreadReply.self)
      })
  }
  
  
}
