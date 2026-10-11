import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum SwiftHighlighter {
    private static let keywords: Set<String> = [
        "import", "class", "struct", "enum", "func", "var", "let", "if", "else",
        "return", "try", "throw", "catch", "guard", "switch", "case", "default",
        "for", "in", "while", "true", "false", "nil", "self", "init", "static",
        "final", "private", "public", "internal", "fileprivate", "async", "await",
        "actor", "protocol", "extension", "some", "any", "where", "as", "is",
        "throws", "do", "defer", "break", "continue", "override", "super", "Self",
        "associatedtype", "typealias", "inout", "mutating", "convenience", "required"
    ]

    static func highlight(_ line: String, colorScheme: ColorScheme) -> AttributedString {
        var result = AttributedString()
        let commentColor = colorScheme == .dark ? Color(red: 0.55, green: 0.78, blue: 0.55) : Color(red: 0.12, green: 0.45, blue: 0.22)
        let stringColor = colorScheme == .dark ? Color(red: 0.95, green: 0.55, blue: 0.40) : Color(red: 0.70, green: 0.20, blue: 0.12)
        let keywordColor = colorScheme == .dark ? Color(red: 0.78, green: 0.62, blue: 0.98) : Color(red: 0.45, green: 0.22, blue: 0.72)
        let numberColor = colorScheme == .dark ? Color(red: 0.55, green: 0.75, blue: 0.95) : Color(red: 0.10, green: 0.35, blue: 0.70)

        let commentStart = line.range(of: "//")
        let codePart = commentStart.map { String(line[..<$0.lowerBound]) } ?? line
        let commentPart = commentStart.map { String(line[$0.lowerBound...]) }

        appendCode(
            codePart,
            to: &result,
            stringColor: stringColor,
            keywordColor: keywordColor,
            numberColor: numberColor
        )
        if let commentPart {
            var comment = AttributedString(commentPart)
            comment.foregroundColor = commentColor
            result += comment
        }
        if result.characters.isEmpty {
            result = AttributedString(" ")
        }
        return result
    }

    private static func appendCode(
        _ code: String,
        to result: inout AttributedString,
        stringColor: Color,
        keywordColor: Color,
        numberColor: Color
    ) {
        var index = code.startIndex
        while index < code.endIndex {
            let character = code[index]
            if character == "\"" {
                let start = index
                index = code.index(after: index)
                while index < code.endIndex && code[index] != "\"" {
                    if code[index] == "\\" {
                        index = code.index(after: index)
                        if index < code.endIndex { index = code.index(after: index) }
                    } else {
                        index = code.index(after: index)
                    }
                }
                if index < code.endIndex { index = code.index(after: index) }
                var chunk = AttributedString(String(code[start..<index]))
                chunk.foregroundColor = stringColor
                result += chunk
            } else if character.isNumber {
                let start = index
                while index < code.endIndex, code[index].isNumber || code[index] == "." {
                    index = code.index(after: index)
                }
                var chunk = AttributedString(String(code[start..<index]))
                chunk.foregroundColor = numberColor
                result += chunk
            } else if character.isLetter || character == "_" || character == "@" || character == "#" {
                let start = index
                index = code.index(after: index)
                while index < code.endIndex, code[index].isLetter || code[index].isNumber || code[index] == "_" {
                    index = code.index(after: index)
                }
                let word = String(code[start..<index])
                var chunk = AttributedString(word)
                if keywords.contains(word) || word.hasPrefix("@") || word.hasPrefix("#") {
                    chunk.foregroundColor = keywordColor
                }
                result += chunk
            } else {
                result += AttributedString(String(character))
                index = code.index(after: index)
            }
        }
    }
}

enum PasteboardCopy {
    static func copy(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }
}
