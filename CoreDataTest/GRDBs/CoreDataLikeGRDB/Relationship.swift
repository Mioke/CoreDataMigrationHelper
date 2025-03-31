//
//  Relationshipo.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/3/4.
//

import Foundation
import GRDB

/*
 The relationship should be read or write under these situations: insertion, updating, query, deleting and relationship updating.
 
 */

public struct OpaqueRelationship {
  
  let reader: (Database, any SeaTalkDatabaseRecord) throws -> Void
  let updater: (Database, any SeaTalkDatabaseRecord) throws -> Void
  let deletion: (Database, any SeaTalkDatabaseRecord) throws -> Void
  
  init<F, T>(
    relationship: RelationshipKind<F, T>,
    inverse: RelationshipKind<T, F>? = nil
  ) where F: SeaTalkDatabaseRecord, T: SeaTalkDatabaseRecord {
    switch relationship {
    case .toOne(_, let keyPath, let to, _):
      // Read - calling when populating relationships.
      reader = { db, object in
        guard var object = object as? F else {
          assertionFailure("The object must be \(F.self), but actual is \(type(of: object))")
          return
        }
        if let primaryKey = object[keyPath: keyPath] {
          let target = try getValueType(to).filterCoreDataPrimaryKey(primaryKey).fetchOne(db)
          // bind target to self.
          object[keyPath: to] = target
        }
      }
      
      // Insertion and updating
      updater = { db, object in
        guard var me = object as? F else {
          assertionFailure("The object must be \(F.self), but actual is \(type(of: object))")
          return
        }
        
        if var target = me[keyPath: to] {
          // update the relationship field using target's primary key
          me[keyPath: keyPath] = target._PK
          // if there's an invserse relationship, update the corresponding object as well.
          if let inverse = inverse {
            switch inverse {
            case .toOne(relationshipName: _, keyPath: let targetsKeyPath, destination: let targetsDestination, deleteRule: _):
              if let oldTargetsTargetPKValue = target[keyPath: targetsKeyPath] {
                // guard the value changes
                if oldTargetsTargetPKValue == me._PK {
                  return
                }
                // if the target has an old relationship obect, set its relationship to nil.
                if var oldTargetsTarget = try getValueType(targetsDestination).filterCoreDataPrimaryKey(oldTargetsTargetPKValue).fetchOne(db) {
                  oldTargetsTarget[keyPath: keyPath] = nil
                }
              }
              // bind self to target.
              target[keyPath: targetsKeyPath] = me._PK
            case .toMany(relationshipName: _, destinationPrimaryKeyPath: _, destination: _, deleteRule: _):
              
              break
            }
          }
        }
      }
      
      // Deletion
      deletion = { db, object in
        guard var me = object as? F else {
          assertionFailure("The object must be \(F.self), but actual is \(type(of: object))")
          return
        }
        
        
      }
      
    case .toMany(let relationshipName, let destinationPrimaryKeyPath, let destination, _):
      reader = { db, object in
        guard var object = object as? F else {
          assertionFailure("The object must be \(F.self), but actual is \(type(of: object))")
          return
        }
        if inverse == nil {
          // query from the inverse table
          let targetType = getDestinationType(destinationPrimaryKeyPath)
          let pk = object._PK
          let columnName = "Z\(object._ENT)\(relationshipName.uppercased())"
          
          let values = try targetType.filter(Column(columnName) == pk).fetchAll(db)
          object[keyPath: destination] = NSSet(array: values)
        }
        
        if case .toOne(let inverseRelationshipName, _, _, _) = inverse {
          // query from the inverse table
          let targetType = getDestinationType(destinationPrimaryKeyPath)
          let pk = object._PK
          let columnName = "Z\(inverseRelationshipName.uppercased())"
          let values = try targetType.filter(Column(columnName) == pk).fetchAll(db)
          object[keyPath: destination] = NSSet(array: values)
        }
        
        if case .toMany(let inverseRelationshipName, _, _, _) = inverse {
          // query from the independent table
          let targetType = getDestinationType(destinationPrimaryKeyPath)
          guard let targetEnt = try _PRIMARYKEY.ENT(of: targetType.databaseTableName, in: db) else {
            fatalError()
          }
          let selfEnt = object._ENT
          let entMark = min(targetEnt, selfEnt)
          let selectedTableName = entMark == targetEnt ? targetType.databaseTableName : F.databaseTableName
          let helperTableName = "Z_\(entMark)\(selectedTableName)"
          
          let selecteColumn = "Z_\(selfEnt)\(relationshipName)"
          let targetColumn = "Z_\(targetEnt)\(inverseRelationshipName)"
          let targetPks = try Row.fetchAll(db, sql: "SELECT * FROM \(helperTableName) WHERE \(selecteColumn) = \(object._PK)")
            .compactMap { $0[targetColumn] as Int64 }
          
          let targets = try targetType.filter(targetPks.contains(Column("Z_PK"))).fetchAll(db)
          object[keyPath: destination] = NSSet(array: targets)
        }
        
      }
      
      updater = { db, object in
        
      }
      
      // Deletion
      deletion = { db, object in
        guard var me = object as? F else {
          assertionFailure("The object must be \(F.self), but actual is \(type(of: object))")
          return
        }
        
        
      }
    }
  }
  
}

private func getValueType<R, V>(_ keyPath: WritableKeyPath<R, V?>) -> V.Type {
  V.self
}

private func getDestinationType<R, V>(_ keyPath: KeyPath<R, V>) -> R.Type {
  R.self
}

public enum RelationshipDeleteRule {
  case noAction
  case nullify
  case cascade
  case deny
}

public enum RelationshipKind<F: SeaTalkDatabaseRecord, T: SeaTalkDatabaseRecord> {
  case toOne(
    relationshipName: String,
    keyPath: WritableKeyPath<F, Int64?>,
    destination: WritableKeyPath<F, T?>,
    deleteRule: RelationshipDeleteRule
  )
  case toMany(
    relationshipName: String,
    destinationPrimaryKeyPath: WritableKeyPath<T, Int64?>,
    destination: WritableKeyPath<F, NSSet>,
    deleteRule: RelationshipDeleteRule
  )
}

extension TableRecord {
  static func filterCoreDataPrimaryKey(_ primaryKey: Int64) -> QueryInterfaceRequest<Self> {
    return filter(Column("Z_PK") == primaryKey)
  }
}
