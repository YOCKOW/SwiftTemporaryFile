/* *************************************************************************************************
 TemporaryFileError.swift
   © 2019-2020,2025 YOCKOW.
     Licensed under MIT License.
     See "LICENSE.txt" for more information.
 ************************************************************************************************ */
 
public enum TemporaryFileError: Swift.Error {
  case alreadyClosed
  case fileCreationFailed
  case invalidURL
  case outOfRange
  case stringConversionFailed
  case dataReadingFailure
}
