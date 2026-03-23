# What is `SwiftTemporaryFile`?

`SwiftTemporaryFile` provides functions related to temporary files.
It was originally written as a part of [SwiftCGIResponder](https://github.com/YOCKOW/SwiftCGIResponder).

# Requirements

- Swift 6.2
- macOS(>=13) or Linux


## Dependencies

<!-- SWIFT PACKAGE DEPENDENCIES MERMAID START -->
```mermaid
---
title: TemporaryFile Dependencies
---
flowchart TD
  swiftranges(["Ranges<br>@4.0.1"])
  swifttemporaryfile["TemporaryFile"]
  swiftunicodesupplement(["UnicodeSupplement<br>@2.0.0"])
  yswiftextensions(["yExtensions<br>@2.0.0"])

  click swiftranges href "https://github.com/YOCKOW/SwiftRanges.git"
  click swiftunicodesupplement href "https://github.com/YOCKOW/SwiftUnicodeSupplement.git"
  click yswiftextensions href "https://github.com/YOCKOW/ySwiftExtensions.git"

  swifttemporaryfile ----> swiftranges
  swifttemporaryfile --> yswiftextensions
  swiftunicodesupplement ----> swiftranges
  yswiftextensions ----> swiftranges
  yswiftextensions --> swiftunicodesupplement


```
<!-- SWIFT PACKAGE DEPENDENCIES MERMAID END -->


# Usage

```Swift
import Foundation
import TemporaryFile

let tmpFile = TemporaryFile()
try! tmpFile.write(contentsOf: "Hello, World!".data(using:.utf8)!)
try! tmpFile.seek(toOffset: 0)
print(String(data: try! tmpFile.readToEnd()!, encoding: .utf8)!) // Prints "Hello, World!"
try! tmpFile.copy(to: URL(fileURLWithPath: "/my/directory/hello.txt"))

/*
You can explicitly close the temporary file by calling `try tmpFile.close()`,
though all of the temporary files are automatically closed at the end of program.
*/
```

```Swift
import TemporaryFile

// You can pass a closure:
TemporaryFile { (tmpFile: TemporaryFile) -> Void in
  try! tmpFile.write(contentsOf: "Hello, World!".data(using:.utf8)!)
  // ... 
} // Automatically closed.
```


# License

MIT License.  
See "LICENSE.txt" for more information.

