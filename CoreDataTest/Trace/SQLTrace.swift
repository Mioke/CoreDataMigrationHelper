//
//  SQLTrace.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/9/27.
//

import SQLite3
import SQLCipher
import Foundation

typealias SQLiteTraceCallback = @convention(c) (
  UInt32,       // Callback code
  UnsafeMutableRawPointer?, // First callback argument (User data)
  UnsafeMutableRawPointer?, // Second callback argument
  UnsafeMutableRawPointer?  // Third callback argument
) -> Int32

class SQLiteProfiler {
  
  enum Exception: Error {
    case databaseCannotOpen(message: String)
  }
  
  enum State {
    case idle
    case working
    case suspended(error: Error)
  }
  
  var state: State = .idle
  let url: URL
  let workerQueue: DispatchQueue = .init(label: "com.mioke.sqlite-profiler")
  
  init(url: URL) {
    self.url = url
  }
  
  public func start() {
    workerQueue.async { [weak self] in
      guard let self else { return }
      do {
        state = .working
        try startProfiler()
      } catch {
        state = .suspended(error: error)
        print("can't start profile with error: \(error)")
      }
    }
  }
  
  var db: OpaquePointer? = nil
  
  private func startProfiler() throws {
    
    guard sqlite3_open(url.path, &db) == SQLITE_OK else {
      throw Exception.databaseCannotOpen(message: String(cString: sqlite3_errmsg(db)))
    }
    
    let status = sqlite3_trace_v2(
      /*db*/db,
      /*trace mask*/UInt32(SQLITE_TRACE_PROFILE),
      /*callback*/{ code, context, pStmt, time in
        let sqlStatement = String(cString: sqlite3_sql(OpaquePointer(pStmt)))
        let executionTime = time.map { Int(bitPattern: $0) } ?? 0
        print("SQL: \(sqlStatement) took \(executionTime) microseconds")
        return SQLITE_OK
      },
      /*context*/nil)
    
    if status != SQLITE_OK {
      print("can't trace with error: \(String(cString: sqlite3_errmsg(db)))")
    }
  }
  
  func tryQuery() {
    let sql = "SELECT * FROM ZMESSAGE"
    executeQuery(sql)
  }
  
  func executeQuery(_ sql: String) {
    var statement: OpaquePointer?
    
    // 准备 SQL 语句
    if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
      // 执行查询
      while sqlite3_step(statement) == SQLITE_ROW {
        // 获取列的数据（假设是一个字符串列）
        if let cString = sqlite3_column_text(statement, 0) {
          let result = String(cString: cString)
          print("Query Result: \(result)")
        }
      }
    } else {
      let errmsg = String(cString: sqlite3_errmsg(db))
      print("Failed to execute query: \(sql). Error: \(errmsg)")
    }
    
    // 释放 SQL 语句
    sqlite3_finalize(statement)
  }
}
