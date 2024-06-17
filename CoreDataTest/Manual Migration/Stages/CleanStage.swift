//
//  CleanStage.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/5/28.
//

import Foundation
import CoreData

class CleanStage: ManualStage {
  static var stageType: ManualMigrator.StageType { .clean }
  var eventReceiver: (any ManualMigratorEventReceiver)?
  
  let sourceURL: URL
  let temporaryURL: URL
  
  init(sourceURL: URL, temporaryURL: URL) {
    self.sourceURL = sourceURL
    self.temporaryURL = temporaryURL
  }
  
  func process() throws {
    let deletingSourceURL = renameSourceFile(sourceURL: sourceURL)
    // if the source db already moved to the deleting url, then skip the move.
    if FileManager.default.fileExists(atPath: deletingSourceURL.path) == false {
      try FileManager.default.moveItem(at: sourceURL, to: deletingSourceURL)
    }
    // if the temporary url has a file there, means the temporary db hasn't been moved to the source url yet.
    if FileManager.default.fileExists(atPath: temporaryURL.path) == true {
      try FileManager.default.moveItem(at: temporaryURL, to: sourceURL)
    }
    try FileManager.default.removeItem(at: deletingSourceURL)
  }
  
  func fallback() {
    // nop
  }
  
  private func renameSourceFile(sourceURL: URL) -> URL {
    let fileName = sourceURL.deletingPathExtension().lastPathComponent
    let ext = sourceURL.pathExtension
    let temporaryFileName = "\(fileName)-deleting.\(ext)"
    return sourceURL.deletingLastPathComponent().appendingPathComponent(temporaryFileName)
  }
}
