import Foundation

struct HttpClient {
    let retryCount: Int
    let retryDelay: TimeInterval

    func performRequest(with request: URLRequest) async throws -> (Data, URLResponse) {
        var attempts = 0
        var lastError: Error?
        while attempts < retryCount {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    throw NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil)
                }
                return (data, response)
            } catch {
                attempts += 1
                lastError = error
                let nserror = error as NSError
                print("Attempt \(attempts) failed: \(nserror) – \(nserror.userInfo). Retrying in \(retryDelay) seconds...")
                try await Task.sleep(nanoseconds: UInt64(retryDelay * Double(NSEC_PER_SEC)))
            }
        }
        throw lastError!
    }
}
