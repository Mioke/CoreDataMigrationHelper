//
//  BidirectionDictionary.swift
//  CoreDataTest
//
//  Created by KelanJiang on 2025/3/27.
//

import Foundation

public struct BidirectionDictionary<T: Hashable, U: Hashable> {
  var forward: [T: U] = [:]
  var backward: [U: T] = [:]
  
  public mutating func update(_ key: T, _ value: U) {
    backward[value] = key
    forward[key] = value
  }
  
  public mutating func removeValue(forKey key: T) {
    guard let value = forward[key] else { return }
    forward[key] = nil
    backward[value] = nil
  }
  
  public mutating func removeValue(forKey key: U) {
    guard let value = backward[key] else { return }
    forward[value] = nil
    backward[key] = nil
  }
  
  public func value(forKey key: T) -> U? {
    forward[key]
  }
  
  public func key(forValue value: U) -> T? {
    backward[value]
  }
  
  public mutating func removeAll() {
    forward.removeAll()
    backward.removeAll()
  }
}
