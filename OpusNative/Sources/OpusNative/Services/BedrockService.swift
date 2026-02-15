import Foundation
import CryptoKit

actor BedrockService {
    private let session = URLSession.shared
    private var region: String = ""
    private var accessKeyId: String = ""
    private var secretAccessKey: String = ""
    
    // MARK: - Main Streaming Function
    func streamResponse(modelId: String, messages: [ChatMessage], systemPrompt: String?, region: String, accessKeyId: String, secretAccessKey: String) async throws -> AsyncThrowingStream<String, Error> {
        self.region = region
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        
        // 1. Construct URL (Manual string to handle the ":" correctly)
        let endpoint = "https://bedrock-runtime.\(region).amazonaws.com/model/\(modelId)/invoke-with-response-stream"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        
        // 2. Prepare Body
        let body = try encodeBody(messages: messages, systemPrompt: systemPrompt)
        
        // 3. Create & Sign Request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        
        try signRequest(request: &request, body: body)
        
        // 4. Execute Request
        let (byteStream, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        // Handle Error Responses
        if !(200...299).contains(httpResponse.statusCode) {
            // Safe Async Error Reading
            var errorData = Data()
            for try await byte in byteStream { errorData.append(byte) }
            let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown Error"
            print("AWS Error Code: \(httpResponse.statusCode)")
            print("AWS Error Body: \(errorText)")
            
            // Surface a human-readable error message
            var message = "AWS Error \(httpResponse.statusCode)"
            if let json = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
               let msg = json["message"] as? String {
                message = msg
            } else if !errorText.isEmpty {
                message = errorText
            }
            throw NSError(domain: "BedrockService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        
        // 5. Decode the AWS Binary Event Stream
        // We return a stream that yields text chunks as we parse them
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in self.decodeEventStream(byteStream) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Internal Binary Decoder (Self-Contained)
    private func decodeEventStream(_ bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                var buffer = Data()
                // Iterate over every byte from the network
                for try await byte in bytes {
                    buffer.append(byte)
                    
                    // Try to process messages in the buffer
                    while true {
                        // AWS EventStream Frame: [TotalLen (4)] [HeaderLen (4)] ...
                        // Minimum valid frame size is roughly 12-16 bytes
                        guard buffer.count >= 8 else { break }
                        
                        let totalLength = buffer.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                        let headerLength = buffer.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).bigEndian }
                        
                        // Wait until we have the full frame
                        guard buffer.count >= Int(totalLength) else { break }
                        
                        // Extract the frame
                        let frameData = buffer.prefix(Int(totalLength))
                        buffer.removeFirst(Int(totalLength))
                        
                        // Isolate Payload (Skip headers and preamble)
                        // Preamble (8) + Headers (headerLength) + Payload + CRC (4)
                        let payloadOffset = 8 + Int(headerLength)
                        let payloadLength = Int(totalLength) - payloadOffset - 4 // Exclude trailing CRC
                        
                        if payloadLength > 0 {
                            let payloadData = frameData.subdata(in: payloadOffset..<(payloadOffset + payloadLength))
                            
                            // Parse the JSON inside the payload
                            if let jsonObject = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
                               let bytesBase64 = jsonObject["bytes"] as? String,
                               let decodedData = Data(base64Encoded: bytesBase64),
                               let innerJSON = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] {
                                
                                // Claude 3 Stream Format: "delta" -> "text"
                                if let type = innerJSON["type"] as? String, type == "content_block_delta",
                                   let delta = innerJSON["delta"] as? [String: Any],
                                   let text = delta["text"] as? String {
                                    continuation.yield(text)
                                }
                            }
                        }
                    }
                }
                continuation.finish()
            }
        }
    }
    
    // MARK: - JSON Encoding
    private func encodeBody(messages: [ChatMessage], systemPrompt: String?) throws -> Data {
        let bedrockMessages = messages.map { ["role": $0.role, "content": [["text": $0.content]]] }
        var payload: [String: Any] = [
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 4096,
            "messages": bedrockMessages
        ]
        if let sys = systemPrompt, !sys.isEmpty { payload["system"] = [["text": sys]] }
        return try JSONSerialization.data(withJSONObject: payload)
    }
    
    // MARK: - AWS V4 Signing
    private func signRequest(request: inout URLRequest, body: Data) throws {
        let date = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        isoFormatter.timeZone = TimeZone(identifier: "UTC")
        let amzDate = isoFormatter.string(from: date).replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
        let dateShort = String(amzDate.prefix(8))
        
        let host = "bedrock-runtime.\(region).amazonaws.com"
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(host, forHTTPHeaderField: "host")
        
        // AWS V4 requires URI-encoding with only unreserved chars (RFC 3986)
        let awsUnreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let canonicalURI = request.url!.path
            .components(separatedBy: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: awsUnreserved) ?? $0 }
            .joined(separator: "/")
        let headers = ["content-type:application/json", "host:\(host)", "x-amz-date:\(amzDate)"]
        let signedHeaders = "content-type;host;x-amz-date"
        let payloadHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        
        let canonicalRequest = """
        POST
        \(canonicalURI)
        
        \(headers.joined(separator: "\n"))
        
        \(signedHeaders)
        \(payloadHash)
        """
        
        let credentialScope = "\(dateShort)/\(region)/bedrock/aws4_request"
        let stringToSign = """
        AWS4-HMAC-SHA256
        \(amzDate)
        \(credentialScope)
        \(SHA256.hash(data: Data(canonicalRequest.utf8)).map { String(format: "%02x", $0) }.joined())
        """
        
        let kDate = hmac(key: ("AWS4" + secretAccessKey).data(using: .utf8)!, data: dateShort.data(using: .utf8)!)
        let kRegion = hmac(key: kDate, data: region.data(using: .utf8)!)
        let kService = hmac(key: kRegion, data: "bedrock".data(using: .utf8)!)
        let kSigning = hmac(key: kService, data: "aws4_request".data(using: .utf8)!)
        let signature = hmac(key: kSigning, data: stringToSign.data(using: .utf8)!).map { String(format: "%02x", $0) }.joined()
        
        let authHeader = "AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
    }
    
    private func hmac(key: Data, data: Data) -> Data {
        let key = SymmetricKey(data: key)
        return Data(HMAC<SHA256>.authenticationCode(for: data, using: key))
    }
}
