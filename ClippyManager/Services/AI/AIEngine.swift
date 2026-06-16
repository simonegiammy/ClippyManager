import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device AI engine wrapping FoundationModels. All FM use is gated to
/// macOS 26; on older systems the methods throw `AIEngineError.unavailable`.
@MainActor
final class AIEngine {

    enum AIEngineError: LocalizedError {
        case unavailable
        case empty
        case unreadableFile
        var errorDescription: String? {
            switch self {
            case .unavailable:    "On-device AI isn't available on this Mac."
            case .empty:          "The model returned no output."
            case .unreadableFile: "This file isn't readable text (e.g. a PDF, image, or binary)."
            }
        }
    }

    // Max characters fed to the model in one shot (small on-device context).
    private let maxInputChars = 6000

    #if canImport(FoundationModels)
    @available(macOS 26, *)
    private var _session: LanguageModelSession? {
        get { _sessionBox as? LanguageModelSession }
        set { _sessionBox = newValue }
    }
    private var _sessionBox: AnyObject?
    #endif

    init() {}

    /// Warm the model so the first token after the palette opens is near-instant.
    func prewarm() {
        #if canImport(FoundationModels)
        guard #available(macOS 26, *) else { return }
        if _session == nil { _session = LanguageModelSession() }
        _session?.prewarm()
        #endif
    }

    /// Reset the conversation (fresh context per transform).
    func resetSession() {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) { _session = LanguageModelSession() }
        #endif
    }

    /// Transform a clip with an action, yielding partial text as it streams.
    /// For `.file` clips, the file's *text contents* are read and used as input.
    func transform(action: AIAction, clip: ClipItem, language: String?) -> AsyncThrowingStream<String, Error> {
        if clip.type == .file {
            guard let fileText = Self.readableText(fromFilePaths: clip.textContent ?? "") else {
                return AsyncThrowingStream { $0.finish(throwing: AIEngineError.unreadableFile) }
            }
            return transform(action: action, text: fileText, language: language)
        }
        return transform(action: action, text: clip.textContent ?? "", language: language)
    }

    /// Reads the contents of the first file path if it's a UTF-8 text document
    /// (txt, md, csv, json, source code…). Returns nil for binaries/PDF/images.
    private static func readableText(fromFilePaths paths: String) -> String? {
        let first = paths.components(separatedBy: "\n").first ?? paths
        guard !first.isEmpty else { return nil }
        let url = URL(fileURLWithPath: first)
        // Only attempt plain-text-ish files.
        let textExts: Set<String> = ["txt","md","markdown","csv","tsv","json","yaml","yml",
                                     "xml","html","htm","swift","js","ts","py","rb","go","rs",
                                     "java","kt","c","cpp","h","sh","log","rtf","tex","srt"]
        let ext = url.pathExtension.lowercased()
        if !textExts.isEmpty && !textExts.contains(ext) {
            // Try anyway only if there's no extension; otherwise bail for binaries.
            if !ext.isEmpty { return nil }
        }
        if let s = try? String(contentsOf: url, encoding: .utf8), !s.isEmpty {
            return s
        }
        return nil
    }

    /// Transform arbitrary text with an action (used for chaining on a result).
    func transform(action: AIAction, text: String, language: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                #if canImport(FoundationModels)
                guard #available(macOS 26, *) else {
                    continuation.finish(throwing: AIEngineError.unavailable); return
                }
                do {
                    try await self.run(action: action, input: text, language: language,
                                       emit: { continuation.yield($0) })
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                #else
                continuation.finish(throwing: AIEngineError.unavailable)
                #endif
            }
        }
    }

    // MARK: - Private

    #if canImport(FoundationModels)
    @available(macOS 26, *)
    private func run(action: AIAction, input rawInput: String, language: String?,
                     emit: @escaping (String) -> Void) async throws {
        let session = LanguageModelSession()      // fresh context each run
        _session = session

        let input = String(rawInput.prefix(maxInputChars))
        let instruction = action.instruction.replacingOccurrences(of: "{lang}", with: language ?? "English")
        let prompt = "\(instruction)\n\n\"\"\"\n\(input)\n\"\"\""

        switch action.outputKind {
        case .text:
            var last = ""
            let stream = session.streamResponse(to: prompt, generating: String.self)
            for try await snapshot in stream {
                last = snapshot.content
                emit(last)
            }
            if last.isEmpty { throw AIEngineError.empty }

        case .bullets:
            let response = try await session.respond(to: prompt, generating: GeneratedBullets.self)
            emit(response.content.asText())

        case .table:
            let response = try await session.respond(to: prompt, generating: GeneratedTable.self)
            emit(response.content.asMarkdown())

        case .json:
            // Generate JSON as text, then validate + pretty-print.
            let response = try await session.respond(to: prompt + "\nReturn only valid minified JSON.",
                                                     generating: String.self)
            emit(Self.prettyJSON(response.content))
        }
    }

    private static func prettyJSON(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj,
                                                       options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            return trimmed   // not valid JSON — show what we got
        }
        return str
    }
    #endif
}
