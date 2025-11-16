/* *************************************************************************************************
 HybridTemporaryFile.swift
   © 2025 YOCKOW.
     Licensed under MIT License.
     See "LICENSE.txt" for more information.
 ************************************************************************************************ */

import Foundation
import yExtensions

/// A type that you can use as a temporary file, which internally holds an instance of
/// `InMemoryFile` or `TemporaryFile`.
public final class HybridTemporaryFile: FileHandleProtocol {
  public static let defaultThreshold: UInt64 = 5 * 1024 * 1024

  private enum _Representation {
    case inMemory(InMemoryFile)
    case onDisk(TemporaryFile)
  }

  private var _representation: _Representation

  internal var _representationIsInMemory: Bool {
    if case .inMemory = _representation {
      return true
    }
    return false
  }

  internal var _representationIsOnDisk: Bool {
    if case .onDisk = _representation {
      return true
    }
    return false
  }

  private let _temporaryDirectory: TemporaryDirectory

  private init(representation: _Representation, temporaryDirectory: TemporaryDirectory) {
    self._representation = representation
    self._temporaryDirectory = temporaryDirectory
  }

  /// A Boolean value that indicates whether or not an instance of `InMemoryFile` should be used
  /// when this "file" is truncated and the size becomes smaller than `threshold`.
  public var usesInMemoryFileWhenTruncated: Bool = false

  /// A value where `TemporaryFile` is used when this "file" becomes larger than it.
  ///
  /// Changing this value will take effect when this file is truncated or some data is written to
  /// this file.
  public var threshold: UInt64 = defaultThreshold

  public convenience init() {
    self.init(representation: .inMemory(InMemoryFile()), temporaryDirectory: .default)
  }

  /// Initializes with specified `temporaryDirectory`.
  /// This directory will be used when creating `TemporaryFile` is required.
  public convenience init(temporaryDirectory: TemporaryDirectory) {
    self.init(representation: .inMemory(InMemoryFile()), temporaryDirectory: temporaryDirectory)
  }

  public func close() throws {
    switch _representation {
    case .inMemory(let inMemoryFile):
      try inMemoryFile.close()
    case .onDisk(let temporaryFile):
      try temporaryFile.close()
    }
  }

  public func offset() throws -> UInt64 {
    switch _representation {
    case .inMemory(let inMemoryFile):
      return try inMemoryFile.offset()
    case .onDisk(let temporaryFile):
      return try temporaryFile.offset()
    }
  }

  @discardableResult
  public func seekToEnd() throws -> UInt64 {
    switch _representation {
    case .inMemory(let inMemoryFile):
      return try inMemoryFile.seekToEnd()
    case .onDisk(let temporaryFile):
      return try temporaryFile.seekToEnd()
    }
  }

  public func seek(toOffset offset: UInt64) throws {
    switch _representation {
    case .inMemory(let inMemoryFile):
      try inMemoryFile.seek(toOffset: offset)
    case .onDisk(let temporaryFile):
      try temporaryFile.seek(toOffset: offset)
    }
  }

  public func synchronize() throws {
    switch _representation {
    case .inMemory(let inMemoryFile):
      try inMemoryFile.synchronize()
    case .onDisk(let temporaryFile):
      try temporaryFile.synchronize()
    }
  }

  public func truncate(atOffset offset: UInt64) throws {
    switch _representation {
    case .inMemory(let inMemoryFile):
      try inMemoryFile.truncate(atOffset: offset)
    case .onDisk(let temporaryFile):
      if usesInMemoryFileWhenTruncated && offset < threshold {
        try temporaryFile.seek(toOffset: 0)
        guard let data = try temporaryFile.read(upToCount: Int(offset)) else {
          throw TemporaryFileError.dataReadingFailure
        }
        try temporaryFile.close()
        let inMemoryFile = InMemoryFile(data)
        try inMemoryFile.seek(toOffset: offset)
        self._representation = .inMemory(inMemoryFile)
      } else {
        try temporaryFile.truncate(atOffset: offset)
      }
    }
  }

  public func read(upToCount count: Int) throws -> Data? {
    switch _representation {
    case .inMemory(let inMemoryFile):
      return try inMemoryFile.read(upToCount: count)
    case .onDisk(let temporaryFile):
      return try temporaryFile.read(upToCount: count)
    }
  }

  public func write<T: DataProtocol>(contentsOf data: T) throws {
    switch _representation {
    case .inMemory(let inMemoryFile):
      let currentOffset = try inMemoryFile.offset()
      if currentOffset + UInt64(data.count) > threshold {
        try inMemoryFile.seek(toOffset: 0)
        guard let currentData = try inMemoryFile.read(upToCount: Int(currentOffset)) else {
          throw TemporaryFileError.dataReadingFailure
        }
        try inMemoryFile.close()

        let temporaryFile = try TemporaryFile(in: _temporaryDirectory)
        try temporaryFile.write(contentsOf: currentData)
        try temporaryFile.write(contentsOf: data)
        self._representation = .onDisk(temporaryFile)
      } else {
        try inMemoryFile.write(contentsOf: data)
      }
    case .onDisk(let temporaryFile):
      try temporaryFile.write(contentsOf: data)
    }
  }

  /// Copy the file to `destination` at which to place the copy of it.
  public func copy(to destination: URL) throws {

    switch _representation {
    case .inMemory(let inMemoryFile):
      if !destination.isExistingLocalFile {
        FileManager.default.createFile(atPath: destination.path, contents: nil)
      }
      let fh = try FileHandle(forWritingTo: destination)
      try fh.write(contentsOf: inMemoryFile)
      try fh.close()
    case .onDisk(let temporaryFile):
      try temporaryFile.copy(to: destination)
    }
  }
}
