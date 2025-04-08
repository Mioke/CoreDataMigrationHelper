//
//  TableUtils.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/4/3.
//

func relationshipColumnName(for relationshipName: String) -> String {
  "Z\(relationshipName.uppercased())"
}

func relationshipColumnName(for relationshipName: String, sourceEntity: Int64) -> String {
  "Z\(sourceEntity)\(relationshipName.uppercased())"
}

func relationshipColumnName<F, T>(
  of relationship: RelationshipKind<F, T>,
  entityID: Int64,
  inversedRelationship: RelationshipKind<T, F>?
) -> String {
  
  switch relationship {
  case .toOne(relationshipName: let name, _, _, _):
    return "Z\(name.uppercased())"
  case .toMany(relationshipName: let relationshipName, _, _, _):
    if let inversedRelationship {
      switch inversedRelationship {
      case .toOne:
        return "Z\(relationshipName)"
      case .toMany(relationshipName: let inversedRelationshipName, _, _, _):
        return "Z\(entityID)\(relationshipName.uppercased())"
      }
    } else {
      return "Z\(entityID)\(relationshipName.uppercased())"
    }
  }
}
