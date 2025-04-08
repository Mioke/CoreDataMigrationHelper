//
//  Relationshipo.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/3/4.
//

import Foundation
import GRDB

public enum RelationshipDeleteRule {
  case noAction
  case nullify
  case cascade
  case deny
}

public enum RelationshipKind<F: SeaTalkDatabaseRecord, T: SeaTalkDatabaseRecord & Hashable> {
  case toOne(
    relationshipName: String,
    keyPath: WritableKeyPath<F, Int64?>,
    destination: WritableKeyPath<F, T?>,
    deleteRule: RelationshipDeleteRule
  )
  case toMany(
    relationshipName: String,
    destinationPrimaryKeyPath: WritableKeyPath<T, Int64?>,
    destination: WritableKeyPath<F, Set<T>?>,
    deleteRule: RelationshipDeleteRule
  )
  
  var relationshipName: String {
    switch self {
    case .toOne(relationshipName: let name, keyPath: _, destination: _, deleteRule: _):
      return name
    case .toMany(relationshipName: let name, destinationPrimaryKeyPath: _, destination: _, deleteRule: _):
      return name
    }
  }
}

/*
 The relationship should be read or write under these situations: insertion, updating, query, deleting and relationship updating.
 */

public struct OpaqueRelationship {
  
  let name: String
  let reader: (Database, any SeaTalkDatabaseRecord) throws -> Void
  let updater: (Database, any SeaTalkDatabaseRecord) throws -> Void
  let deletion: (Database, any SeaTalkDatabaseRecord) throws -> Void
  
  init<F, T>(
    relationship: RelationshipKind<F, T>,
    inverse: RelationshipKind<T, F>? = nil
  ) where F: SeaTalkDatabaseRecord, T: SeaTalkDatabaseRecord {
    //
    name = relationship.relationshipName
    
    switch relationship {
    case .toOne(_, let keyPath, let to, let deleteRule):
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
        guard var target = me[keyPath: to] else { return }
        // check target has been saved.
        guard target._PK != 0 else {
          throw SeaTalkDatabase.Exception.relationshipObjectIsTemporary
        }
        
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
                try oldTargetsTarget.update(in: db)
              }
            }
            // bind self to target.
            target[keyPath: targetsKeyPath] = me._PK
          case .toMany(relationshipName: _, destinationPrimaryKeyPath: _, destination: _, deleteRule: _):
            // if inverse is to-many, acturely there's no other table or column to be updated, because the relationship
            // is maintained on current entity.
            break
          }
        }
      }
      
      // Deletion
      deletion = { db, object in
        guard let me = object as? F else {
          assertionFailure("The object must be \(F.self), but actual is \(type(of: object))")
          return
        }
        
        guard let targetPK = me[keyPath: keyPath], targetPK > 0 else { return }
        
        switch deleteRule {
        case .nullify:
          // if thers's no inverse relationship, no other action is needed.
          guard let inverse else { return }
          
          switch inverse {
          case .toOne(relationshipName: let inverseName, keyPath: _, destination: let destination, deleteRule: _):
            // set inverse relation to nil
            let assignment = Column(relationshipColumnName(for: inverseName)).set(to: nil)
            try getValueType(destination).filterCoreDataPrimaryKey(targetPK).updateAll(db, assignment)
            
          case .toMany(relationshipName: let relationshipName, destinationPrimaryKeyPath: _, destination: let destination, deleteRule: _):
            let assignment = Column(relationshipColumnName(for: relationshipName)).set(to: nil)
            try getRootType(destination).filterCoreDataPrimaryKey(targetPK).updateAll(db, assignment)
          }
        case .cascade:
          // how to solve the cycle reference relationship..
          Self.dfs_deletion(db: db, object: object)
          break
        default: assertionFailure("not implemented"); return
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
          let targetType = getRootType(destinationPrimaryKeyPath)
          let pk = object._PK
          let columnName = "Z\(object._ENT)\(relationshipName.uppercased())"
          
          let values = try targetType.filter(Column(columnName) == pk).fetchAll(db)
          object[keyPath: destination] = Set<T>(values)
        }
        
        if case .toOne(let inverseRelationshipName, _, let destinationKeyPath, _) = inverse {
          // query from the inverse table
          let targetType = getRootType(destinationPrimaryKeyPath)
          let pk = object._PK
          let columnName = "Z\(inverseRelationshipName.uppercased())"
          var values = try targetType.filter(Column(columnName) == pk).fetchAll(db)
          // NOTE: - Performance consuming?
          values = values.compactMap {
            var newObject = $0
            newObject[keyPath: destinationKeyPath] = object
            return newObject
          }
          object[keyPath: destination] = Set<T>(values)
        }
        
        if case .toMany(let inverseRelationshipName, _, _, _) = inverse {
          // query from the independent table
          let targetType = getRootType(destinationPrimaryKeyPath)
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
          object[keyPath: destination] = Set<T>(targets)
        }
        
      }
      
      updater = { db, object in
        guard let me = object as? F else {
          assertionFailure("The object must be \(F.self), but actual is \(type(of: object))")
          return
        }
        
        if let inverse, case .toMany(_, _, _, _) = inverse {
          
        } else /* no inverse or inverse is to-one, the implementation is the same. */{
          // find the origin relationship targets, differ them with current object relationship value, split it into
          // two array contains inserted and deleted, update the record in database.
          guard let current = me[keyPath: destination] else { return }
          let targetType: T.Type = getRootType(destinationPrimaryKeyPath)
          let origin = Set(try targetType.filterCoreDataPrimaryKey(me._PK).fetchAll(db))
          
          let deleted = origin.subtracting(current).map { $0._PK }
          let inserted = current.subtracting(origin).map { $0._PK }
          
          // TODO: - check this
          let columnName: String
          if case .toOne(let inverseRelationshipName, _, _, _) = inverse {
            columnName = relationshipColumnName(for: inverseRelationshipName)
          } else {
            columnName = relationshipColumnName(for: relationshipName, sourceEntity: me._ENT)
          }
          
          try targetType.filter(deleted.contains(Column("Z_PK"))).updateAll(db, Column(columnName).set(to: nil))
          try targetType.filter(inserted.contains(Column("Z_PK"))).updateAll(db, Column(columnName).set(to: me._PK))
        }
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
  
  static func dfs_deletion<T>(db: Database, object: T) {
    
  }
  
}

private func getValueType<R, V>(_ keyPath: WritableKeyPath<R, V?>) -> V.Type {
  V.self
}

private func getRootType<R, V>(_ keyPath: KeyPath<R, V>) -> R.Type {
  R.self
}

extension TableRecord {
  static func filterCoreDataPrimaryKey(_ primaryKey: Int64) -> QueryInterfaceRequest<Self> {
    return filter(Column("Z_PK") == primaryKey)
  }
}
