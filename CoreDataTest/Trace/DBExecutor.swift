//
//  DBExecutor.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/3/10.
//

import Foundation
import SQLite3
import SQLCipher

public final class DatabaseExecutor {
  
  public enum Error: Swift.Error {
    case databaseCannotOpen(message: String)
    case databaseNotOpen
    case isExecuting
    case executionError(message: String)
  }
  
  public enum State {
    case closed
    case opening(executing: Bool)
  }
  
  public var url: URL
  var db: OpaquePointer? = nil
  
  public var state: State = .closed
  
  var queue: DispatchQueue = .init(label: "com.seagroup.seatalk.message.database.executor")
  
  public init(url: URL) {
    self.url = url
  }
  
  public func connectIfNeeded() throws {
    try queue.sync {
      guard case .closed = state else {
        return
      }
      guard sqlite3_open(url.path, &db) == SQLITE_OK else {
        throw Error.databaseCannotOpen(message: String(cString: sqlite3_errmsg(db)))
      }
      self.state = .opening(executing: false)
    }
  }
  
  public func close() throws {
    try queue.sync {
      guard case .opening(let executing) = state, let db = self.db else {
        return
      }
      
      guard executing == false else {
        throw Error.isExecuting
      }
      
      guard sqlite3_close(db) == SQLITE_OK else {
        throw Error.executionError(message: String(cString: sqlite3_errmsg(db)))
      }
      self.db = nil
      self.state = .closed
    }
  }
  
  public func execute(_ sql: String) throws -> [[String: Any]] {
    return try queue.sync {
      guard case .opening(let executing) = state, let db = self.db else {
        throw Error.databaseNotOpen
      }
      
      guard executing == false else {
        throw Error.isExecuting
      }
      
      var statement: OpaquePointer? = nil
      
      if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
        throw Error.executionError(message: String(cString: sqlite3_errmsg(db)))
      }
      defer { sqlite3_finalize(statement) }
      
      var results: [[String: Any]] = []
      // 执行查询并处理结果
      while sqlite3_step(statement) == SQLITE_ROW {
        let columnCount = sqlite3_column_count(statement) // 获取列数
        var row: [String: Any] = [:]
        // 遍历每一列
        for columnIndex in 0..<columnCount {
          let columnName = String(cString: sqlite3_column_name(statement, columnIndex)) // 列名
          let columnType = sqlite3_column_type(statement, columnIndex) // 列类型
          
          // 根据列类型获取值
          var value: Any = "NULL"
          switch columnType {
          case SQLITE_INTEGER:
            value = Int64(sqlite3_column_int(statement, columnIndex))
          case SQLITE_FLOAT:
            value = sqlite3_column_double(statement, columnIndex)
          case SQLITE_TEXT:
            value = String(cString: sqlite3_column_text(statement, columnIndex))
          case SQLITE_BLOB:
            if let blobPointer = sqlite3_column_blob(statement, columnIndex) {
              let blobSize = sqlite3_column_bytes(statement, columnIndex)
              value = Data(bytes: blobPointer, count: Int(blobSize))
            }
          case SQLITE_NULL:
            value = "NULL"
          default:
            value = "UNKNOWN"
          }
          
          row[columnName] = value
          // 打印列名和值
          print("\(columnName): \(value)")
        }
        results.append(row)
        print("----") // 分隔每一行结果
      }
      
      return results
    }
  }
  
}
