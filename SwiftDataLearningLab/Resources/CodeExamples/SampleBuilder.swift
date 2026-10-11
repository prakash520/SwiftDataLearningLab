import Foundation

enum Samples {
    static func make(
        _ id: String,
        _ title: String,
        _ source: String,
        _ notes: [(String, String)]
    ) -> CodeSample {
        CodeSample(
            id: id,
            title: title,
            source: source.trimmingCharacters(in: .whitespacesAndNewlines),
            annotations: notes.map { CodeAnnotation(anchor: $0.0, explanation: $0.1) }
        )
    }
}
