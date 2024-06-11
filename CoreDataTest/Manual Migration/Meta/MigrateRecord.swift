//
//  MigrateRecord.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/6/4.
//

import Foundation
import CoreData

extension MigrateRecord {
  
  static func fetch(with name: String, in context: NSManagedObjectContext) throws -> MigrateRecord? {
    let request = MigrateRecord.fetchRequest()
    request.predicate = NSPredicate(format: "name == %@", argumentArray: ["\(name)"])
    return try context.fetch(request).first
  }
  
  static func fetchOrCreate(with name: String, in context: NSManagedObjectContext) throws -> MigrateRecord {
    if let record = try fetch(with: name, in: context) { return record }
    let record = MigrateRecord(context: context)
    record.name = name
    try context.save()
    return record
  }
  
  static func update(with name: String, in context: NSManagedObjectContext, updateBlock: (MigrateRecord) -> Void) throws {
    try context.performAndWait {
      guard let object = try fetch(with: name, in: context) else { return }
      updateBlock(object)
      try context.save()
    }
  }
  
  enum Status: Int {
    case processing = 0
    case finished = 1
  }
  
  var status: Status {
    get {
      return .init(rawValue: Int(statusValue)) ?? .finished
    }
    set {
      statusValue = Int16(newValue.rawValue)
    }
  }
}
