/* *************************************************************************************************
 TemporaryFileHandle.swift
   © 2019 YOCKOW.
     Licensed under MIT License.
     See "LICENSE.txt" for more information.
 ************************************************************************************************ */

import Foundation

// `FileHandle` of Foundation in Objective-C is an abstract class.
// It is too hard to make a subclass that inherits from `FileHandle` in Swift.
// So the workaround is to use Objective-C to make it.
// See "TemporafyFileHandle" target.

private func _unavailable(_ function:StaticString = #function) -> Never {
  fatalError("\(function) is unavailable because the instance is a TemporaryFile's filehandle.")
}

#if canImport(ObjectiveC)
import TemporaryFileHandle
private typealias _Parent = __TemporaryFileHandle
#else
private typealias _Parent = FileHandle
#endif

private final class _TemporaryFileHandle: _Parent {
  #if canImport(ObjectiveC)
  private var _temporaryFile: TemporaryFile { return self.__temporaryFile as! TemporaryFile }
  init(_ temporaryFile:TemporaryFile) {
    super.init(temporaryFile: temporaryFile)
  }
  #else
  private weak var _temporaryFile: TemporaryFile!
  init(_ temporaryFile:TemporaryFile) {
    super.init(fileDescriptor:temporaryFile._fileHandle.fileDescriptor, closeOnDealloc: false)
    self._temporaryFile = temporaryFile
  }
  #endif
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var availableData: Data { return self._temporaryFile.availableData }
  override func closeFile() { _unavailable() }
  override var fileDescriptor: Int32 { _unavailable() }
  override var offsetInFile: UInt64 { return self._temporaryFile.offsetInFile }
  override func readData(ofLength length: Int) -> Data { return self._temporaryFile.readData(ofLength:length) }
  override func readDataToEndOfFile() -> Data { return self._temporaryFile.readDataToEndOfFile() }
  override func seek(toFileOffset offset: UInt64) { self._temporaryFile.seek(toFileOffset:offset) }
  override func seekToEndOfFile() -> UInt64 { return self._temporaryFile.seekToEndOfFile() }
  override func truncateFile(atOffset offset: UInt64) { return self._temporaryFile.truncateFile(atOffset:offset) }
  override func write(_ data: Data) { self._temporaryFile.write(data) }
}

extension TemporaryFile {
  /// An instance of a subclass of `FileHandle`.
  /// The functionality is very limited to avoid unexpected `close`.
  /// You can just read and write data via the file handle.
  /// Of course, you can do so with the methods of `TemporaryFile`.
  /// It means this property is used only when you want an instance of `FileHandle`.
  public var fileHandle: FileHandle {
    return _TemporaryFileHandle(self)
  }
}
