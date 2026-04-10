import Foundation

#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

public struct CapabilityInvocation: Sendable {
    public let providerFamily: String
    public let arguments: [String: RuntimeValue]
    public let variables: [String: RuntimeValue]

    public init(providerFamily: String, arguments: [String: RuntimeValue], variables: [String: RuntimeValue]) {
        self.providerFamily = providerFamily
        self.arguments = arguments
        self.variables = variables
    }
}

public typealias CapabilityHandler = @Sendable (CapabilityInvocation) async throws -> RuntimeValue

public actor CapabilityRegistry {
    private var handlers: [String: CapabilityHandler]

    public init(registerBuiltins: Bool = true) {
        self.handlers = registerBuiltins ? Self.builtinHandlers() : [:]
    }

    public static func standard() -> CapabilityRegistry {
        CapabilityRegistry(registerBuiltins: true)
    }

    public func register(_ name: String, handler: @escaping CapabilityHandler) {
        handlers[name] = handler
    }

    public func contains(_ name: String) -> Bool {
        handlers[name] != nil
    }

    public func names() -> [String] {
        handlers.keys.sorted()
    }

    public func invoke(_ name: String, invocation: CapabilityInvocation) async throws -> RuntimeValue {
        guard let handler = handlers[name] else {
            throw RuleEngineError.missingCapability(name)
        }
        return try await handler(invocation)
    }

    private static func builtinHandlers() -> [String: CapabilityHandler] {
        [
            "extract.regexLinks": { invocation in
                let text = stringArgument(named: "html", in: invocation.arguments)
                    ?? stringArgument(named: "text", in: invocation.arguments)
                    ?? ""
                let pattern = stringArgument(named: "pattern", in: invocation.arguments)
                    ?? #"https?://[^"'\s<]+"#
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                let links = regex.matches(in: text, range: range).compactMap { match -> String? in
                    guard let matchRange = Range(match.range, in: text) else {
                        return nil
                    }
                    return String(text[matchRange])
                }
                return .array(links.map(RuntimeValue.string))
            },
            "json.lookup": { invocation in
                let source = invocation.arguments["json"] ?? .null
                let path = invocation.arguments["path"]?.arrayValue?.compactMap(\.stringValue) ?? []
                guard let root = jsonRuntimeValue(from: source) else {
                    return .null
                }
                return lookup(path: path, from: root) ?? .null
            },
            "payload.formURLEncoded": { invocation in
                let fields = invocation.arguments["fields"]?.objectValue ?? [:]
                let pairs = fields
                    .sorted { $0.key < $1.key }
                    .map { key, value in
                        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
                        let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                        let escapedValue = value.renderedString().addingPercentEncoding(withAllowedCharacters: allowed) ?? value.renderedString()
                        return "\(escapedKey)=\(escapedValue)"
                    }
                return .string(pairs.joined(separator: "&"))
            },
            "cookies.normalize": { invocation in
                let values = invocation.arguments["cookies"]?.arrayValue ?? []
                var cookies = [CookieKey: SerializableCookie]()
                for item in values {
                    guard let object = item.objectValue else {
                        continue
                    }
                    let cookie = SerializableCookie(
                        name: object["name"]?.stringValue ?? "",
                        value: object["value"]?.stringValue ?? "",
                        domain: object["domain"]?.stringValue ?? "",
                        path: object["path"]?.stringValue ?? "/",
                        expiresAt: nil,
                        secure: object["secure"]?.boolValue ?? false,
                        httpOnly: object["httpOnly"]?.boolValue ?? false
                    )
                    cookies[CookieKey(cookie)] = cookie
                }
                return .array(cookies.values.sorted { $0.name < $1.name }.map(\.runtimeValue))
            },
            "cookies.valueForName": { invocation in
                guard let expectedName = stringArgument(named: "name", in: invocation.arguments)?.lowercased() else {
                    throw RuleEngineError.invalidTemplate("cookies.valueForName requires name")
                }
                let cookies = invocation.arguments["cookies"]?.arrayValue ?? []
                for item in cookies.reversed() {
                    guard let object = item.objectValue,
                          object["name"]?.stringValue?.lowercased() == expectedName else {
                        continue
                    }
                    return object["value"] ?? .null
                }
                return .null
            },
            "tokens.join": { invocation in
                let values = invocation.arguments["tokens"]?.arrayValue?.map { $0.renderedString() } ?? []
                let separator = stringArgument(named: "separator", in: invocation.arguments) ?? ""
                return .string(values.joined(separator: separator))
            },
            "string.asciiHexMD5": { invocation in
                guard let text = stringArgument(named: "text", in: invocation.arguments) else {
                    throw RuleEngineError.invalidTemplate("string.asciiHexMD5 requires text")
                }
                let ascii = text.unicodeScalars.map { String(format: "%d", $0.value) }.joined()
                guard let data = ascii.data(using: .utf8) else {
                    throw RuleEngineError.invalidTemplate("string.asciiHexMD5 could not encode text")
                }
                let digest = Insecure.MD5.hash(data: data)
                return .string(digest.map { String(format: "%02x", $0) }.joined())
            },
            "url.origin": { invocation in
                guard let source = stringArgument(named: "sourceURL", in: invocation.arguments),
                      let url = URL(string: source),
                      let scheme = url.scheme,
                      let host = url.host else {
                    throw RuleEngineError.invalidTemplate("url.origin requires a valid sourceURL")
                }
                let portSuffix = url.port.map { ":\($0)" } ?? ""
                return .string("\(scheme)://\(host)\(portSuffix)")
            },
            "rosefile.appendDownPath": { invocation in
                guard let source = stringArgument(named: "sourceURL", in: invocation.arguments),
                      let url = URL(string: source),
                      var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                    throw RuleEngineError.invalidTemplate("rosefile.appendDownPath requires sourceURL")
                }
                if !components.path.hasPrefix("/d/") {
                    components.path = "/d\(components.path)"
                }
                guard let result = components.url?.absoluteString else {
                    throw RuleEngineError.invalidTemplate("rosefile.appendDownPath could not rebuild URL")
                }
                return .string(result)
            },
        ]
    }
}

private struct CookieKey: Hashable {
    let name: String
    let domain: String
    let path: String

    init(_ cookie: SerializableCookie) {
        self.name = cookie.name.lowercased()
        self.domain = cookie.domain.lowercased()
        self.path = cookie.path
    }
}

private func stringArgument(named key: String, in arguments: [String: RuntimeValue]) -> String? {
    arguments[key]?.stringValue
}

private func jsonRuntimeValue(from source: RuntimeValue) -> RuntimeValue? {
    if case .object = source {
        return source
    }
    guard let string = source.stringValue,
          let data = string.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let value = RuntimeValue.from(jsonObject: object) else {
        return nil
    }
    return value
}

private func lookup(path: [String], from root: RuntimeValue) -> RuntimeValue? {
    guard !path.isEmpty else {
        return root
    }

    var current = root
    for segment in path {
        if let index = Int(segment), let array = current.arrayValue, array.indices.contains(index) {
            current = array[index]
            continue
        }
        guard let object = current.objectValue, let next = object[segment] else {
            return nil
        }
        current = next
    }
    return current
}
