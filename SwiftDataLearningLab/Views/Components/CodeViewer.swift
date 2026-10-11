import SwiftUI

struct CodeViewer: View {
    let sample: CodeSample
    @Environment(\.colorScheme) private var colorScheme
    @State private var copied = false

    private var lines: [String] {
        sample.source.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(sample.title)
                    .font(.headline)
                Spacer()
                Button {
                    PasteboardCopy.copy(sample.source)
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy code", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .accessibilityLabel("Copy code")
            }

            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 28, alignment: .trailing)
                                .accessibilityHidden(true)
                            Text(SwiftHighlighter.highlight(line, colorScheme: colorScheme))
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 1)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Line \(index + 1). \(line)")
                    }
                }
                .padding(12)
            }
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !sample.annotations.isEmpty {
                Text("Key lines")
                    .font(.subheadline.weight(.semibold))
                ForEach(resolvedAnnotations) { item in
                    DisclosureGroup("Line \(item.line): \(item.annotation.anchor)") {
                        Text(item.annotation.explanation)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .accessibilityHint("Shows the explanation for this line")
                }
            }
        }
        .onChange(of: copied) { _, isCopied in
            guard isCopied else { return }
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        }
    }

    private var resolvedAnnotations: [ResolvedAnnotation] {
        sample.annotations.compactMap { annotation in
            guard let index = lines.firstIndex(where: { $0.contains(annotation.anchor) }) else { return nil }
            return ResolvedAnnotation(line: index + 1, annotation: annotation)
        }
    }
}

private struct ResolvedAnnotation: Identifiable {
    let line: Int
    let annotation: CodeAnnotation
    var id: String { annotation.id }
}

struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct LabStatusBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("Playground status")
            .accessibilityValue(text)
    }
}

struct LevelBadge: View {
    let level: SkillLevel

    var body: some View {
        Text(level.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.18), in: Capsule())
            .accessibilityLabel("\(level.title) topic")
    }

    private var color: Color {
        switch level {
        case .beginner: .green
        case .intermediate: .orange
        case .advanced: .purple
        }
    }
}
