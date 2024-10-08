/* *************************************************************************************************
 InMemoryFile.swift
   © 2019-2020,2024 YOCKOW.
     Licensed under MIT License.
     See "LICENSE.txt" for more information.
 ************************************************************************************************ */

import Foundation
import Ranges
import yExtensions
import yProtocols

@available(*, deprecated, renamed: "InMemoryFile")
public typealias FileHandleCompatibleData = InMemoryFile

/// A byte buffer in memory that is (limitedly) compatible with `FileHandle`.
/// You can use this class instead of `TemporaryFile` for a specific purpose.
open class InMemoryFile: FileHandleProtocol {
  private var _data: Data
  private var _offset: Int = 0
  private var _isClosed: Bool = false
  
  private init(_data data: Data) {
    self._data = data
  }
  
  public convenience required init() {
    self.init(_data: Data())
  }
  
  public convenience required init<S>(_ elements: S) where S: Sequence, S.Element == UInt8 {
    if case let data as Data = elements {
      self.init(_data: data)
    } else {
      self.init(_data: Data(elements))
    }
  }
  
  open func isEqual(to file: InMemoryFile) -> Bool {
    return self._data == file._data
  }
  
  public static func ==(lhs: InMemoryFile, rhs: InMemoryFile) -> Bool {
    return lhs.isEqual(to:rhs)
  }
  
  open func hash(into hasher: inout Hasher) {
    hasher.combine(self._data)
  }
  
  open func close() throws {
    self._isClosed = true
  }
  
  public func offset() throws -> UInt64 {
    return UInt64(self._offset)
  }
  
  public func read(upToCount count: Int) throws -> Data? {
    if self._isClosed { return nil }
    
    let end: Int = self._data.count - self._offset < count ? self._data.count : self._offset + count
    defer { self._offset = end - self._data.startIndex}
    
    return self._data[relativeBounds: self._offset..<end]
  }
  
  public func readToEnd() throws -> Data? {
    return try self.read(upToCount: Int.max)
  }
  
  public func seek(toOffset offset: UInt64) throws {
    guard offset >= 0 && offset <= self._data.count else { throw TemporaryFileError.outOfRange }
    self._offset = Int(offset)
  }
  
  @discardableResult
  public func seekToEnd() throws -> UInt64 {
    let endOffset = UInt64(self._data.count)
    try self.seek(toOffset: endOffset)
    return endOffset
  }
  
  public func synchronize() throws {
    // do nothing
  }
  
  public func truncate(atOffset offset: UInt64) throws {
    if offset > UInt64(self._data.count) {
      self._data += Data(count: Int(offset) - self._data.count)
    } else {
      self._data = self._data[relativeBounds: 0..<Int(offset)]
    }
    self._offset = Int(offset)
  }
  
  public func write<T>(contentsOf data: T) throws where T : DataProtocol {
    for byte: UInt8 in data {
      if self._offset < self._data.count {
        self._data[relativeIndex: self._offset] = byte
      } else {
        self._data.append(byte)
      }
      self._offset += 1
    }
  }
  
  public func write<Target>(to target: inout Target) throws where Target: DataOutputStream {
    try target.write(contentsOf: self._data)
  }
  
  /// Creates an empty buffer of a specified size.
  public convenience init(capacity: Int) {
    self.init(_data: Data(capacity: capacity))
  }
  
  /// Creates a new buffer with the specified count of zeroed bytes.
  public convenience init(count: Int) {
    self.init(_data: Data(count: count))
  }
  
  open var isEmpty: Bool {
    return self._data.isEmpty
  }
  
  open var count: Int {
    return self._data.count
  }
  
  /// Copies the contents of the data to memory.
  open func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, count: Int) {
    self._data.copyBytes(to: pointer, count: count)
  }
}

extension InMemoryFile: Sequence, IteratorProtocol {
  public typealias Element = Data.Element
  public typealias Iterator = InMemoryFile
  
  public func next() -> Data.Element? {
    guard self._offset < self._data.count else { return nil }
    defer { self._offset += 1 }
    return self._data[relativeIndex: self._offset]
  }
}

extension InMemoryFile: Collection {
  public typealias Index = Int
  
  public subscript(position: Int) -> Data.Element {
    get {
      return self._data[relativeIndex: position]
    }
    set {
      self._data[relativeIndex: position] = newValue
    }
  }
  
  public var startIndex: Int { return 0 }
  
  public var endIndex: Int { return self._data.count }
  
  public func index(after ii: Int) -> Int {
    return ii + 1
  }
}

extension InMemoryFile: BidirectionalCollection {
  public func index(before ii: Int) -> Int {
    return ii - 1
  }
}

extension InMemoryFile: RandomAccessCollection {}

extension InMemoryFile: MutableCollection, RangeReplaceableCollection {
  public func append<S>(contentsOf newElements: S) where S: Sequence, S.Element == Data.Element {
    self._data.append(contentsOf:newElements)
  }
  
  public func reserveCapacity(_ nn: Int) {
    self._data.reserveCapacity(nn)
  }

  public func replaceSubrange<C>(
    _ subrange: Range<Int>,
    with newElements: C
  ) where C: Collection, Data.Element == C.Element {
    self._data.replaceSubrange(subrange, with: newElements)
  }
}

extension InMemoryFile: ContiguousBytes {
  public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    return try self._data.withUnsafeBytes(body)
  }
}

extension InMemoryFile: DataProtocol {
  public typealias Regions = CollectionOfOne<InMemoryFile>
  
  public var regions: CollectionOfOne<InMemoryFile> {
    return CollectionOfOne(self)
  }
}

extension InMemoryFile: MutableDataProtocol {
  public func resetBytes<R: RangeExpression>(in range: R) where R.Bound == Index {
    self._data.resetBytes(in: range)
  }
}
