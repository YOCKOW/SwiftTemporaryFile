#if !canImport(ObjectiveC)
import XCTest

extension TemporaryFileTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__TemporaryFileTests = [
        ("test_temporaryDirectory", test_temporaryDirectory),
        ("test_temporaryFile", test_temporaryFile),
        ("test_temporaryFile_closure", test_temporaryFile_closure),
        ("test_temporaryFile_copy", test_temporaryFile_copy),
        ("test_temporaryFile_truncate", test_temporaryFile_truncate),
        ("test_temporaryFileHandle", test_temporaryFileHandle),
        ("test_UUID", test_UUID),
    ]
}

public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(TemporaryFileTests.__allTests__TemporaryFileTests),
    ]
}
#endif
