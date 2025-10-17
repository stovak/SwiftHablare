//
//  GuionDocumentModel+Conversion.swift
//  SwiftHablare
//
//  Extension to convert between GuionDocumentModel and GuionParsedScreenplay
//

import Foundation
import SwiftGuion

extension GuionDocumentModel {
    /// Convert GuionDocumentModel back to FountainScript
    ///
    /// This ensures proper element ordering, as SwiftData relationships don't
    /// preserve insertion order. The FountainScript uses standard arrays
    /// which maintain order.
    ///
    /// If rawContent is available, it will be parsed to ensure proper order.
    /// Otherwise, it will use the SwiftData elements (which may be unordered).
    ///
    /// - Returns: A FountainScript with elements in proper screenplay order
    public func toFountainScript() -> FountainScript {
        // If we have rawContent, parse it to get properly ordered elements
        if let content = rawContent, !content.isEmpty {
            do {
                let script = try FountainScript(string: content)
                script.filename = filename
                script.suppressSceneNumbers = suppressSceneNumbers

                // Copy title page if available
                if !titlePage.isEmpty {
                    var titlePageDict: [String: [String]] = [:]
                    for entry in titlePage {
                        titlePageDict[entry.key] = entry.values
                    }
                    if !titlePageDict.isEmpty {
                        script.titlePage = [titlePageDict]
                    }
                }

                return script
            } catch {
                // Fall through to manual conversion if parsing fails
            }
        }

        // Fallback: Convert elements from SwiftData models (may be unordered)
        let guionElements = elements.map { elementModel in
            GuionElement(from: elementModel)
        }

        // Convert title page entries back to dictionary format
        var titlePageDictionaries: [[String: [String]]] = []
        if !titlePage.isEmpty {
            var currentDict: [String: [String]] = [:]
            for entry in titlePage {
                currentDict[entry.key] = entry.values
            }
            if !currentDict.isEmpty {
                titlePageDictionaries.append(currentDict)
            }
        }

        let script = FountainScript()
        script.filename = filename
        script.elements = guionElements
        script.titlePage = titlePageDictionaries
        script.suppressSceneNumbers = suppressSceneNumbers
        return script
    }
}
