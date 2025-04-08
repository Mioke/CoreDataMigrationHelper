//
//  BatchOperations.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/3/10.
//

import Foundation
import GRDB

// NOTE: - Be careful using different kind of transaction type: `deffered`, `exclusive`, `immediately`

public protocol BatchOperationRequest {
  var notifyChanges: Bool { get set }
}

public struct BatchInsertionRequest: BatchOperationRequest {
  public var notifyChanges: Bool = false
  
}

public struct BatchDeletionRequest: BatchOperationRequest {
  public var notifyChanges: Bool = false
}

public struct BatchUpdateRequest: BatchOperationRequest {
  public var notifyChanges: Bool = false
}
