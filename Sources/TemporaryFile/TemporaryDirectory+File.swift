/* *************************************************************************************************
 TemporaryDirectory+File.swift
   © 2018-2021,2024 YOCKOW.
     Licensed under MIT License.
     See "LICENSE.txt" for more information.
 ************************************************************************************************ */

import Dispatch
import Foundation
import yExtensions
import yProtocols

/// Represents a temporary file.
public typealias TemporaryFile = TemporaryDirectory.File

/// Represents a temporary directory.
/// The temporary directory on the disk will be removed in `deinit`.
public final class TemporaryDirectory {
  /// Represents a temporary file.
  /// The file is created always in some temporary directory represented by `TemporaryDirectory`.
  public final class File: Hashable {
    /*
      An instance of this class has no longer any file handle.
      All functions delegates its parent directory (i.e. `_temporaryDirectory`).
      Such implementation was triggered by https://github.com/YOCKOW/SwiftCGIResponder/pull/72
      (Error: Attempted to read deallocated object.)
    */

    internal unowned let _temporaryDirectory: TemporaryDirectory

    private lazy var _identifier: ObjectIdentifier = .init(self)

    fileprivate init(temporaryDirectory: TemporaryDirectory) {
      _temporaryDirectory = temporaryDirectory
    }

    public static func ==(lhs: File, rhs: File) -> Bool {
      return lhs._identifier == rhs._identifier
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(_identifier)
    }
  }

  fileprivate struct _FileSubstance {
    let fileHandle: FileHandle
    let url: URL

    init(fileHandle: FileHandle, url: URL) {
      self.fileHandle = fileHandle
      self.url = url
    }
  }

  fileprivate var _fileSubstanceTable: [File: _FileSubstance] = [:]

  public private(set) var isClosed: Bool = false

  internal let _url: URL // testable

  /// Use the directory at `url` temporarily.
  private init(_directoryAt url:URL) {
    assert(url.isExistingLocalDirectory, "Directory doesn't exist at \(url.absoluteString)")
    self._url = url
  }

  /// Create a temporary directory. The path to the temporary directory will be
  /// "/path/to/parentDirectory/prefix[random string]suffix".
  /// - parameter parentDirectory: The path to the directory that will contain the temporary directory.
  /// - parameter prefix: The prefix of the name of the temporary directory.
  /// - parameter suffix: The suffix of the name of the temporary directory.
  public convenience init(
    in parentDirectory: URL = .temporaryDirectory,
    prefix: String = "jp.YOCKOW.TemporaryFile",
    suffix: String = ".\(String(ProcessInfo.processInfo.processIdentifier, radix: 10))"
  ) throws {
    let parent = parentDirectory.resolvingSymlinksInPath()
    guard parent.isExistingLocalDirectory else { throw TemporaryFileError.invalidURL }
    let uuid = UUID().base32EncodedString()
    let tmpDirURL = parent.appendingPathComponent("\(prefix)\(uuid)\(suffix)", isDirectory: true)
    try FileManager.default.createDirectoryWithIntermediateDirectories(
      at: tmpDirURL,
      attributes: [.posixPermissions: NSNumber(value: Int16(0o700))]
    )
    self.init(_directoryAt: tmpDirURL)
  }

  @available(*, deprecated, renamed: "init(in:prefix:suffix:)")
  public convenience init(
    inParentDirectoryAt url:URL,
    prefix:String = "jp.YOCKOW.TemporaryFile/",
    suffix:String = ".\(ProcessInfo.processInfo.processIdentifier)"
  ) {
    try! self.init(in: url, prefix: prefix, suffix: suffix)
  }

  /// Remove all temporary files in the temporary directory represented by the receiver.
  public func closeAllTemporaryFiles() throws {
    for file in _fileSubstanceTable.keys {
      try _close(file: file)
    }
  }

  @available(*, deprecated, renamed: "closeAllTemporaryFiles()")
  @discardableResult public func removeAllTemporaryFiles() -> Bool {
    do {
      try self.closeAllTemporaryFiles()
    } catch {
      return false
    }
    return true
  }

  /// Close the temporary directory represented by the receiver.
  /// All of the temporary files in the temporary directory will be removed.
  /// The directory itself will be also removed.
  public func close() throws {
    if self.isClosed { throw TemporaryFileError.alreadyClosed }
    try self.closeAllTemporaryFiles()
    try FileManager.default.removeItem(at: self._url)
    self.isClosed = true
  }

  deinit {
    try? self.close()
  }
}

// MARK: - Default Temporary Directory

private let _defaultTemporaryDirectoryQueue = DispatchQueue(
  label: "jp.YOCKOW.TemporaryFile.DefaultTemporaryDirectory",
  attributes: .concurrent
)

private func _clean() {
  _defaultTemporaryDirectoryQueue.sync(flags: .barrier) {
    guard let defaultTemporaryDir = TemporaryDirectory._default else { return }
    try? defaultTemporaryDir.close()
    TemporaryDirectory._default = nil
  }
}

extension TemporaryDirectory {
  nonisolated(unsafe) fileprivate static var _default: TemporaryDirectory? = nil

  /// The default temporary directory.
  public static var `default`: TemporaryDirectory {
    return _defaultTemporaryDirectoryQueue.sync(flags: .barrier) {
      guard let defaultTemporaryDir = _default else {
        let newDefault = try! TemporaryDirectory()
        _default = newDefault
        atexit(_clean)
        return newDefault
      }
      return defaultTemporaryDir
    }
  }
}

// MARK: /Default Temporary Directory -

extension TemporaryDirectory.File {
  /// Create a temporary file in `temporaryDirectory`.
  /// The filename will be "prefix[random string]suffix".
  public convenience init(
    in temporaryDirectory: TemporaryDirectory = .default,
    prefix: String = "",
    suffix: String = "",
    contents data: Data? = nil
  ) throws {
    if temporaryDirectory.isClosed { throw TemporaryFileError.alreadyClosed }
    let filename = prefix + UUID().base32EncodedString() + suffix
    let url = temporaryDirectory._url.appendingPathComponent(filename, isDirectory: false)
    guard FileManager.default.createFile(
      atPath: url.path,
      contents: data,
      attributes: [.posixPermissions: NSNumber(value: Int16(0o600))]
    ) else {
      throw TemporaryFileError.fileCreationFailed
    }
    self.init(temporaryDirectory: temporaryDirectory)

    let fh = try FileHandle(forUpdating: url)
    let substance = TemporaryDirectory._FileSubstance(fileHandle: fh, url: url)
    temporaryDirectory._fileSubstanceTable[self] = substance
  }

  public var isClosed: Bool {
    return _temporaryDirectory._fileSubstanceTable[self] == nil
  }
}

extension TemporaryDirectory {
  private func _substance(for file: File) throws -> _FileSubstance {
    guard let substance = _fileSubstanceTable[file] else { throw TemporaryFileError.alreadyClosed }
    return substance
  }

  internal func _fileHandle(for file: File) throws -> FileHandle {
    return try _substance(for: file).fileHandle
  }

  fileprivate func _close(file: File) throws {
    let substance = try _substance(for: file)
    try substance.fileHandle.close()
    _fileSubstanceTable[file] = nil
    try FileManager.default.removeItem(at: substance.url)
  }

  fileprivate func _offset(in file: File) throws -> UInt64 {
    return try _fileHandle(for: file).offset()
  }

  fileprivate func _read(file: File, upToCount count: Int) throws -> Data? {
    return try _fileHandle(for: file).read(upToCount: count)
  }

  fileprivate func _seek(file: File, toOffset offset: UInt64) throws {
    try _fileHandle(for: file).seek(toOffset: offset)
  }

  fileprivate func _seekToEnd(of file: File) throws -> UInt64 {
    try _fileHandle(for: file).seekToEnd()
  }

  fileprivate func _synchronize(file: File) throws {
    try _fileHandle(for: file).synchronize()
  }

  fileprivate func _truncate(file: File, atOffset offset: UInt64) throws {
    try _fileHandle(for: file).truncate(atOffset: offset)
  }

  fileprivate func _write<D>(contentsOf data: D, to file: File) throws where D: DataProtocol {
    try _fileHandle(for: file).write(contentsOf: data)
  }
}

extension TemporaryDirectory.File: FileHandleProtocol {
  public func close() throws {
    try _temporaryDirectory._close(file: self)
  }

  public func offset() throws -> UInt64 {
    return try _temporaryDirectory._offset(in: self)
  }

  public func read(upToCount count: Int) throws -> Data? {
    return try _temporaryDirectory._read(file: self, upToCount: count)
  }

  public func seek(toOffset offset: UInt64) throws {
    try _temporaryDirectory._seek(file: self, toOffset: offset)
  }

  @discardableResult
  public func seekToEnd() throws -> UInt64 {
    return try _temporaryDirectory._seekToEnd(of: self)
  }

  public func synchronize() throws {
    try _temporaryDirectory._synchronize(file: self)
  }

  public func truncate(atOffset offset: UInt64) throws {
    try _temporaryDirectory._truncate(file: self, atOffset: offset)
  }

  public func write<D>(contentsOf data: D) throws where D: DataProtocol {
    try _temporaryDirectory._write(contentsOf: data, to: self)
  }
}


extension TemporaryDirectory: Hashable {
  public static func ==(lhs: TemporaryDirectory, rhs: TemporaryDirectory) -> Bool {
    return lhs._url.path == rhs._url.path
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self._url.path)
  }
}

extension TemporaryDirectory.File {
  /// Create a temporary file and execute the closure passing the temporary file as an argument.
  @discardableResult
  public convenience init(_ body: (TemporaryFile) throws -> Void) rethrows {
    try! self.init()
    defer { try? self.close() }
    try body(self)
  }
}

extension TemporaryDirectory.File {
  /// Copy the file to `destination` at which to place the copy of it.
  /// This method calls `FileManager.copyItem(at:to:) throws` internally.
  public func copy(to destination: URL) throws {
    let url = try _temporaryDirectory._substance(for: self).url
    try FileManager.default.copyItem(at: url, to: destination)
  }
}

