//
//  DefaultMigrationStage.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2024/5/28.
//

import Foundation
import CoreData

class DefaultMigrationStage: ManualStage {
  static var stageType: ManualMigrator.StageType { .defaultMigration }
  var eventReceiver: (any ManualMigratorEventReceiver)?
  
  let sourceModel: NSManagedObjectModel
  let targetModel: NSManagedObjectModel
  let ignoreEntities: [String]
  let sourceReader: RawCoreDataReader
  let targetURL: URL
  let meta: NSManagedObjectContext
  
  var targetContext: NSManagedObjectContext {
    get throws {
      try MigrateUtils.createContext(using: targetModel, at: targetURL, readOnly: false)
    }
  }
  
  var relationshipMapping: RelationshipMapping = .init()
  
  init(sourceModel: NSManagedObjectModel, 
       targetModel: NSManagedObjectModel,
       ignoreEntities: [String],
       sourceReader: RawCoreDataReader,
       targetURL: URL,
       meta: NSManagedObjectContext) {
    self.sourceModel = sourceModel
    self.targetModel = targetModel
    self.ignoreEntities = ignoreEntities
    self.sourceReader = sourceReader
    self.targetURL = targetURL
    self.meta = meta
  }
  
  func process() throws {
    try transmit(entities: compareModels())
  }
  
  func fallback() {
    // can simplify to delete the temporary store, then recreate one.
  }
}

extension DefaultMigrationStage {
  
  /// Compare models between entities.
  /// - Returns: model names.
  func compareModels() -> [String] {
    return sourceModel.entitiesByName.compactMap { (key: String, value: NSEntityDescription) in
      if targetModel.entitiesByName[key] != nil {
        return key
      } else { return nil }
    }
//    .sorted(by: <)
  }
  
  // TODO: - unidirection relationship not implemented.
  func buildUnidirectionReferenceTree() {}

  /// If there's a cycle relationship between entities, we should break the cycle and store one of the entities with
  /// all the reference from old store to new store. After the data transmition, restore the relationship we broked
  /// before.
  ///
  /// for example: A -> B -> C -> A, break the cycle to A -> B -> C, and store all the [A -> A']. After transmition
  /// restore C' -> A' using the [A -> A'] and item mapping.
  func checkUnidirectionReferenceTreeHasCircle() -> Bool { false }
  
  /// If there are unidirction relationships between entities, priority should be given to migrating the entity at the
  /// top of the reference.
  /// - Parameter entities: entities description
  /// - Returns: sorted entities.
  func sort(entities: [NSEntityDescription]) -> [NSEntityDescription] { entities }
  
  /// Transmit models
  /// - Parameter entities: Entity names
  func transmit(entities: [String]) throws {
    let targetContext = try self.targetContext
    try entities.forEach {
//      guard let record = try skip(entity: $0) else { return }
      try self.read(entity: $0, to: targetContext)
    }
  }
  
  func skip(entity: String) throws -> MigrateRecord? {
    let record = try MigrateRecord.fetchOrCreate(with: entity, in: meta)
    if case .finished = record.status {
      return nil
    } else {
      return record
    }
  }
  
  /// Read from old store, trasmit it to the target store('s context).
  /// - Parameters:
  ///   - entity: entity description
  ///   - targetContext: targetContext
  func read(entity: String, to targetContext: NSManagedObjectContext) throws {
    try sourceReader.fetchAllEntities(
      entityName: entity
      /*from: Int(record.batchOffset)*/)
    { (entities, nextOffset, isFinal) in
      // TODO: - can handle each object asynchronously?
      try entities.forEach { try handleEach(object: $0, entityName: entity, to: targetContext) }
      try targetContext.save()
      eventReceiver?.receive(event: .batchInserted(entity, entities.count))
    }
  }
  
  private func handleEach(object: NSManagedObject, entityName: String, to targetContext: NSManagedObjectContext) throws {
    guard let sourceEntityDesc = self.sourceModel.entitiesByName[entityName],
          let targetEntityDesc = self.targetModel.entitiesByName[entityName]
    else {
      assertionFailure("Should both have, because we filter the entities before."); return;
    }
    let propertyValues = self.propertyValueMap(of: object, withDescription: sourceEntityDesc)
    let relationshipValues = self.relationshipValueMap(of: object,
                                                       withEntity: sourceEntityDesc,
                                                       ignoreEntities: self.ignoreEntities)
    try insert(using: propertyValues,
               relationshipValues: relationshipValues,
               in: targetContext,
               targetEntity: targetEntityDesc)
  }
  
  @available(*, unavailable, message: "not implemented now")
  private func save(targetContext: NSManagedObjectContext, record: MigrateRecord) throws {
    try targetContext.save()
    do {
      try meta.save()
    } catch {
      targetContext.rollback()
      throw error
    }
  }
  
  typealias RelationshipValueItem = (name: String,
                                     old: NSManagedObject,
                                     related: NSManagedObject,
                                     relationshipType: RelationshipType)
  
  /// Core data insert operation
  /// - Parameters:
  ///   - propertyValues: property-value array.
  ///   - relationshipValues: relationship-value array.
  ///   - context: target context.
  ///   - entity: Entity description.
  func insert(
    using propertyValues: [(String, Any?)],
    relationshipValues: [RelationshipValueItem],
    in context: NSManagedObjectContext,
    targetEntity entity: NSEntityDescription
  ) throws -> Void {
    let object = NSEntityDescription.insertNewObject(forEntityName: entity.name!, into: context)
    propertyValues.forEach { (key, value) in object.setPrimitiveValue(value, forKey: key) }
    // The newly inserted object may have a temporary ObjectID which will make the update logic below throwing an error
    // says `Dangling Object`.
    if object.objectID.isTemporaryID {
      try context.obtainPermanentIDs(for: [object])
    }
    // store the relationships
    let inserting = relationshipValues.compactMap { item -> RelationshipMappingItem? in
      let item = RelationshipMappingItem(
        relationshipName: item.name,
        type: item.relationshipType,
        sourceObjectID: item.old.objectID,
        sourceValueObjectID: item.related.objectID,
        targetObjectID: object.objectID
      )
      if case .bidirection = item.type, let exsiting = self.relationshipMapping.checkBindingItem(using: item) {
        self.updateRelationship(using: exsiting, targetContext: context)
        self.relationshipMapping.removeBidirectionRelationshipItem(by: exsiting.sourceObjectID)
        return nil
      }
      return item
    }
    relationshipMapping.insertRelatinshipItems(inserting)
  }
  
  /// Update relationship using mapping item.
  /// - Parameters:
  ///   - item: Mapping item.
  ///   - targetContext: target context.
  func updateRelationship(using item: RelationshipMappingItem, targetContext: NSManagedObjectContext) {
    guard let targetValueObjectID = item.targetValueObjectID else { assertionFailure("Should checked before"); return }
    let targetObject = targetContext.object(with: item.targetObjectID)
    let targetValueObject = targetContext.object(with: targetValueObjectID)
    targetObject.setPrimitiveValue(targetValueObject, forKey: item.relationshipName)
  }
  
  /// Util function: get property-value map.
  /// - Parameters:
  ///   - object: object.
  ///   - entityDescription: entityDescription descriptio
  /// - Returns: Property-value map array.
  private func propertyValueMap(of object: NSManagedObject,
                                withDescription entityDescription: NSEntityDescription) 
  -> [(String, Any?)] {
    let relationships = Array(entityDescription.relationshipsByName.keys)
    return entityDescription.properties.compactMap { desc -> (String, Any?)? in
      guard !desc.isTransient, !relationships.contains(desc.name) else { return nil }
      return (desc.name, object.primitiveValue(forKey: desc.name))
    }
  }
  
  /// Util function: get relationship-value map.
  /// - Parameters:
  ///   - object: object description
  ///   - entityDescription: entityDescription description
  ///   - ignoreEntities: ignoreEntities
  /// - Returns: Relationship-value map array.
  private func relationshipValueMap(
    of object: NSManagedObject,
    withEntity entityDescription: NSEntityDescription,
    ignoreEntities: [String]
  ) -> [RelationshipValueItem] {
    return entityDescription.relationshipsByName
      .compactMap { (key: String, value: NSRelationshipDescription) -> RelationshipValueItem? in
        // ignore the custom migration entity.
        if let targetName = value.destinationEntity?.name, ignoreEntities.contains(targetName) { return nil }
        guard let relateObject = object.primitiveValue(forKey: key) as? NSManagedObject else { return nil }
        return (key, object, relateObject, .init(inverseRelationship: value.inverseRelationship))
      }
  }
  
}

extension DefaultMigrationStage {
  
  enum RelationshipType {
    case unidirection
    case bidirection
    
    init(inverseRelationship: NSRelationshipDescription?) {
      if inverseRelationship == nil {
        self = .unidirection
      } else {
        self = .bidirection
      }
    }
  }
  
  /// before: A1--<relationshiop-name>-->B1, after: A2--<relationship-name>-->B2.
  /// `sourceObjectId`: A1
  /// `sourceValueObjectID`: B1
  /// `targetObjectId`: A2
  /// `targetValueObjectID`: B2
  ///
  /// When B2 haven't been transmitted, the targetValueObjectID should be nil. But when the relationship mapping item is
  /// built, The `sourceObjectId`, `sourceValueObjectID`, `targetObjectId` are not nil.
  struct RelationshipMappingItem {
    let relationshipName: String
    let type: RelationshipType
    
    /// The object id of the entity in source core data.
    let sourceObjectID: NSManagedObjectID
    /// The object id of the relationship entity in source core data.
    let sourceValueObjectID: NSManagedObjectID

    /// The object id of the entity in target core data.
    let targetObjectID: NSManagedObjectID
    /// The object id of the relationship entity in target core data.
    var targetValueObjectID: NSManagedObjectID?
  }
  
  struct RelationshipMapping {
    var bidirectionRelationshipMapUsingSourceObjectId: [NSManagedObjectID: RelationshipMappingItem] = [:]
    var unidirectionRelationshipMapUsingSourceValueObjectId: [NSManagedObjectID: RelationshipMappingItem] = [:]
    
    mutating func insertRelatinshipItems(_ items: [RelationshipMappingItem]) {
      items.forEach {
        switch $0.type {
        case .unidirection: unidirectionRelationshipMapUsingSourceValueObjectId[$0.sourceValueObjectID] = $0
        case .bidirection: bidirectionRelationshipMapUsingSourceObjectId[$0.sourceObjectID] = $0
        }
      }
    }
    
    // MARK: - Bidirection relationship
    /// If item exists like [A1 : A1\B1\A2], we are checking B1: B1\A1\B2, so the sourceValueObjectID is A1.
    func checkBindingItem(using mappingItem: RelationshipMappingItem) -> RelationshipMappingItem? {
      if var existingItem = checkBindingItem(using: mappingItem.sourceValueObjectID) {
        existingItem.targetValueObjectID = mappingItem.targetObjectID
        return existingItem
      }
      return nil
    }
    
    /// If item exists like [A1 : A1\B1\A2], we are checking B1: B1\A1\B2, so the sourceValueObjectID is A1.
    private func checkBindingItem(using sourceValueObjectID: NSManagedObjectID) -> RelationshipMappingItem? {
      return bidirectionRelationshipMapUsingSourceObjectId[sourceValueObjectID]
    }
    
    mutating func removeBidirectionRelationshipItem(by sourceObjectID: NSManagedObjectID) {
      assert(bidirectionRelationshipMapUsingSourceObjectId[sourceObjectID] != nil)
      bidirectionRelationshipMapUsingSourceObjectId[sourceObjectID] = nil
    }
    
    // MARK: - Unidirection relationship
  }
}

