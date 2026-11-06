import Foundation

/// Une valeur JSON quelconque : les messages du connecteur Claude, leurs arguments et leurs réponses.
enum JSONValue: Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    subscript(key: String) -> JSONValue? {
        if case .object(let fields) = self { return fields[key] }
        return nil
    }

    var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// Un entier, y compris écrit « 3.0 » ou « "3" ».
    var int: Int? {
        switch self {
        case .int(let value): value
        case .double(let value) where value == value.rounded(): Int(exactly: value)
        case .string(let value): Int(value.trimmingCharacters(in: .whitespaces))
        default: nil
        }
    }

    var bool: Bool? {
        switch self {
        case .bool(let value): value
        case .string(let value) where value == "true": true
        case .string(let value) where value == "false": false
        default: nil
        }
    }

    var array: [JSONValue]? {
        if case .array(let values) = self { return values }
        return nil
    }

    var object: [String: JSONValue]? {
        if case .object(let fields) = self { return fields }
        return nil
    }

    var isNull: Bool { self == .null }

    // MARK: Texte

    static func parse(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    /// Sur une ligne, clés triées : un message JSON-RPC.
    var compact: String { encoded(pretty: false) }

    /// Indenté, clés triées : le texte rendu à Claude.
    var pretty: String { encoded(pretty: true) }

    private func encoded(pretty: Bool) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return "null" }
        return String(decoding: data, as: UTF8.self)
    }
}

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let values): try container.encode(values)
        case .object(let fields): try container.encode(fields)
        }
    }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral,
    ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .int(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}
