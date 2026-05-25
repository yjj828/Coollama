import Foundation
import OSLog

@MainActor
final class OllamaClient: ObservableObject {
    @Published var baseURL: String
    @Published var lastError: String?

    private let session: URLSession
    private static let logger = Logger(subsystem: "com.coollama.app", category: "OllamaClient")

    init(baseURL: String = "http://127.0.0.1:11434") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        self.session = URLSession(configuration: config)
    }

    func updateBaseURL(_ url: String) {
        baseURL = url
    }

    /// 拼接 API 路径，保留 baseURL 自带的上下文路径（例如反向代理前缀 `/ollama`）
    private func apiURL(path: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else {
            throw OllamaError.invalidURL
        }
        if components.scheme == nil {
            components.scheme = "http"
        }
        var basePath = components.path
        if basePath.hasSuffix("/") { basePath.removeLast() }
        let suffix = path.hasPrefix("/") ? path : "/\(path)"
        components.path = basePath + suffix
        guard let url = components.url else {
            throw OllamaError.invalidURL
        }
        return url
    }

    func fetchModels() async throws -> [OllamaModelInfo] {
        let url = try apiURL(path: "api/tags")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            lastError = nil
            return decoded.models.sorted { $0.name < $1.name }
        } catch let error as OllamaError {
            lastError = error.localizedMessage(language: AppLanguageStore.shared.language)
            throw error
        } catch {
            let message = error.localizedDescription
            lastError = AppLocalizer.format(
                .unableToConnectOllama,
                language: AppLanguageStore.shared.language,
                baseURL
            )
            throw OllamaError.connectionFailed(message)
        }
    }

    func testConnection() async -> Bool {
        do {
            _ = try await fetchModels()
            return true
        } catch {
            return false
        }
    }

    func chatStream(
        model: String,
        messages: [APIMessage],
        think: ThinkParameter?
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = try self.apiURL(path: "api/chat")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body = ChatRequest(model: model, messages: messages, stream: true, think: think)
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await self.session.bytes(for: request)
                    try self.validate(response: response)

                    for try await line in bytes.lines {
                        if Task.isCancelled { throw CancellationError() }
                        guard !line.isEmpty else { continue }
                        guard let data = line.data(using: .utf8) else { continue }

                        let chunk: ChatStreamChunk
                        do {
                            chunk = try JSONDecoder().decode(ChatStreamChunk.self, from: data)
                        } catch {
                            Self.logger.warning(
                                "\(AppLocalizer.format(.skippedMalformedStreamLine, language: AppLanguageStore.shared.language, line), privacy: .public)"
                            )
                            continue
                        }

                        if let thinking = chunk.message?.thinking, !thinking.isEmpty {
                            continuation.yield(.thinkingDelta(thinking))
                        }
                        if let content = chunk.message?.content, !content.isEmpty {
                            continuation.yield(.contentDelta(content))
                        }
                        if chunk.done {
                            continuation.yield(.done(chunk))
                            continuation.finish()
                            return
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch let error as OllamaError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: OllamaError.connectionFailed(error.localizedDescription))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func validate(response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw OllamaError.httpError(http.statusCode, body)
        }
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw OllamaError.httpError(
                http.statusCode,
                AppLocalizer.string(.requestFailed, language: AppLanguageStore.shared.language)
            )
        }
    }
}
