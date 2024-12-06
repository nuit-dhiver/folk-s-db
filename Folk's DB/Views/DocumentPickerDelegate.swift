//
//  DocumentPickerDelegate.swift
//  Folk's DB
//
//  Created by Mohammad-Hossein Emami on 06.12.24.
//
import UIKit

class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("File saved to: \(urls.first?.path ?? "Unknown location")")
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Document picker was cancelled.")
    }
}
