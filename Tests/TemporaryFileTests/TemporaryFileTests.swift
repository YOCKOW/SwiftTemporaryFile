/* *************************************************************************************************
 TemporaryFileTests.swift
   © 2018-2020,2024-2025 YOCKOW.
     Licensed under MIT License.
     See "LICENSE.txt" for more information.
 ************************************************************************************************ */

@testable import TemporaryFile
import yExtensions
import yProtocols
import Foundation
import Testing

@Suite struct TemporaryFileTests {
  @Test func test_temporaryDirectory() throws {
    let tmpDir = try TemporaryDirectory(prefix: "jp.YOCKOW.TemporaryFile.test.")
    #expect(tmpDir._url.isExistingLocalDirectory)
    try tmpDir.close()
    #expect(!tmpDir._url.isExistingLocalDirectory)
  }

  @Test func test_temporaryFile() throws {
    let expectedString = "Hello!"
    let tmpFile = try TemporaryFile(suffix:".txt", contents: expectedString.data(using: .utf8)!)
    let data = tmpFile.availableData

    guard let string = String(data:data, encoding:.utf8) else {
      Issue.record("Unexpected data.")
      return
    }
    #expect(expectedString == string)
  }

  @Test func test_temporaryFile_closure() throws {
    let closed = try TemporaryFile { (tmpFile:TemporaryFile) -> Void in
      let data = Data([0,1,2,3,4])
      let dataLength = UInt64(data.count)

      try tmpFile.seek(toOffset:0)
      try tmpFile.write(contentsOf: data)
      #expect(try tmpFile.offset() == dataLength)

      try tmpFile.seek(toOffset:0)
      #expect(tmpFile.availableData == data)

      try tmpFile.truncate(atOffset:0)
      #expect(try tmpFile.offset() == 0)
      try tmpFile.seek(toOffset:0)
      #expect(tmpFile.availableData.count == 0)
    }
    #expect(closed.isClosed)
  }

  @Test func test_temporaryFile_copy() throws {
    let data = Data([0,1,2,3,4])
    let tmpFile = try TemporaryFile(contents: data)

    let destination = URL.temporaryDirectory.appendingPathComponent(
      "jp.YOCKOW.TemporaryFile.test." + UUID().base32EncodedString(),
      isDirectory:false
    )

    try tmpFile.copy(to: destination)

    let copied = AnyFileHandle(try FileHandle(forReadingFrom: destination))
    defer { try? copied.close() }

    #expect(copied.availableData == data)

    try FileManager.default.removeItem(at: destination)
  }

  @Test func test_temporaryFile_truncate() throws {
    let data = "Hello!".data(using:.utf8)!
    let tmpFile = try TemporaryFile(contents: data)

    try tmpFile.write(contentsOf: data)
    try tmpFile.seek(toOffset: 0)
    #expect(tmpFile.availableData == data)

    try tmpFile.truncate(atOffset: 5)
    try tmpFile.seek(toOffset: 0)
    #expect(String(data:tmpFile.availableData, encoding:.utf8) == "Hello")
  }

  @Test func test_process() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "echo TEST"]

    let stdout = try TemporaryFile()
    process[.standardOutput] = stdout

    try process.run()
    process.waitUntilExit()

    try stdout.seek(toOffset: 0)
    #expect(try stdout.readToEnd().flatMap({ String(data: $0, encoding: .utf8) }) == "TEST\n")
  }
}


@Suite struct InMemoryFileTests {
  @Test func test_inMemoryFile() throws {
    let fhData = InMemoryFile()
    #expect(fhData.isEmpty)

    try fhData.write(contentsOf: Data([0x00, 0x01, 0x02, 0x03]))
    #expect(fhData.count == 4)

    try fhData.seek(toOffset: 2)
    #expect(fhData.availableData == Data([0x02, 0x03]))

    try fhData.seek(toOffset: 3)
    try fhData.write(contentsOf: Data([0x04, 0x05]))
    try fhData.seek(toOffset: 0)
    #expect(fhData.availableData == Data([0x00, 0x01, 0x02, 0x04, 0x05]))
  }

  @Test func test_inMemoryFile_sequence() throws {
    let fhData = InMemoryFile([0x00, 0x01])
    #expect(fhData.next() == 0x00)
    #expect(try fhData.offset() == 1)
    #expect(fhData.next() == 0x01)
    #expect(try fhData.offset() == 2)
    #expect(fhData.next() == nil)
  }

  @Test func test_inMemoryFile_collection() {
    let fhData = InMemoryFile([0x00, 0x01])
    #expect(fhData[1] == 0x01)
  }

  @Test func test_inMemoryFile_mutableCollection() {
    var fhData = InMemoryFile([0xFF, 0x00])
    fhData.sort()
    #expect(fhData[0] == 0x00)
    #expect(fhData[1] == 0xFF)
  }

  @Test func test_inMemoryFile_rangeReplaceableCollection() {
    let fhData1 = InMemoryFile()
    #expect(fhData1.count == 0)

    let fhData2 = InMemoryFile(repeating:0xFF, count:100)
    #expect(fhData2.count == 100)
    #expect(fhData2.randomElement() == 0xFF)
  }

  @Test func test_inMemoryFile_mutableDataProtocol() {
    let fhData = InMemoryFile([0xFF, 0xFF, 0xFF, 0xFF])
    fhData.resetBytes(in: 1...2)
    #expect(fhData.availableData == Data([0xFF, 0x00, 0x00, 0xFF]))
  }
}


@Suite struct HybridTemporaryFileTests {
  @Test func test_inMemoryFile() throws {
    let tmp = HybridTemporaryFile()
    #expect(tmp._representationIsInMemory)

    try tmp.write(contentsOf: Data(
      repeating: 0xFF,
      count: Int(HybridTemporaryFile.defaultThreshold - 1)
    ))
    #expect(tmp._representationIsInMemory)
    #expect(try tmp.offset() == HybridTemporaryFile.defaultThreshold - 1)

    try tmp.seek(toOffset: 0)
    let data = try #require(try tmp.readToEnd())
    #expect(data.allSatisfy({ $0 == 0xFF }))

    try tmp.truncate(atOffset: 10)
    try tmp.seek(toOffset: 0)
    let truncatedData = try #require(try tmp.readToEnd())
    #expect(truncatedData.count == 10)
    #expect(truncatedData.allSatisfy({ $0 == 0xFF }))
  }

  @Test func test_onDiskFile() throws {
    let tmp = HybridTemporaryFile()
    #expect(tmp._representationIsInMemory)

    try tmp.write(contentsOf: Data(
      repeating: 0xFF,
      count: Int(HybridTemporaryFile.defaultThreshold * 2)
    ))
    #expect(tmp._representationIsOnDisk)
    #expect(try tmp.offset() == HybridTemporaryFile.defaultThreshold * 2)

    try tmp.seek(toOffset: 0)
    let data = try #require(try tmp.readToEnd())
    #expect(data.allSatisfy({ $0 == 0xFF }))

    try tmp.truncate(atOffset: 20)
    #expect(tmp._representationIsOnDisk)
    try tmp.seek(toOffset: 0)
    let truncatedDataOnDisk = try #require(try tmp.readToEnd())
    #expect(truncatedDataOnDisk.count == 20)
    #expect(truncatedDataOnDisk.allSatisfy({ $0 == 0xFF }))

    tmp.usesInMemoryFileWhenTruncated = true
    try tmp.truncate(atOffset: 10)
    #expect(tmp._representationIsInMemory)
    try tmp.seek(toOffset: 0)
    let truncatedDataInMemory = try #require(try tmp.readToEnd())
    #expect(truncatedDataInMemory.count == 10)
    #expect(truncatedDataInMemory.allSatisfy({ $0 == 0xFF }))
  }

  @Test func test_copy() throws {
    let data = Data([0,1,2,3,4])

    let tmpFile = HybridTemporaryFile()
    try tmpFile.write(contentsOf: data)

    let destination = URL.temporaryDirectory.appendingPathComponent(
      "jp.YOCKOW.HybridTemporaryFile.test." + UUID().base32EncodedString(),
      isDirectory: false
    )

    try tmpFile.copy(to: destination)

    let copied = try FileHandle(forReadingFrom: destination)
    defer { try? copied.close() }

    #expect(copied.availableData == data)

    try FileManager.default.removeItem(at: destination)
  }
}
