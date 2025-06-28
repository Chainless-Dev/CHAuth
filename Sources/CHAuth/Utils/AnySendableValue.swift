import Foundation

@frozen
public enum AnySendableValue: Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case url(URL)
    case data(Data)
    case array([AnySendableValue])
    case dictionary([String: AnySendableValue])
    case null
    
    public init(_ value: Any) {
        switch value {
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let double as Double:
            self = .double(double)
        case let bool as Bool:
            self = .bool(bool)
        case let date as Date:
            self = .date(date)
        case let url as URL:
            self = .url(url)
        case let data as Data:
            self = .data(data)
        case let array as [Any]:
            self = .array(array.map(AnySendableValue.init))
        case let dict as [String: Any]:
            self = .dictionary(dict.mapValues(AnySendableValue.init))
        default:
            self = .null
        }
    }
    
    public var value: Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .date(let value):
            return value
        case .url(let value):
            return value
        case .data(let value):
            return value
        case .array(let values):
            return values.map(\.value)
        case .dictionary(let dict):
            return dict.mapValues(\.value)
        case .null:
            return NSNull()
        }
    }
    
    public var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
    
    public var intValue: Int? {
        if case .int(let value) = self {
            return value
        }
        return nil
    }
    
    public var doubleValue: Double? {
        if case .double(let value) = self {
            return value
        }
        return nil
    }
    
    public var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }
    
    public var dateValue: Date? {
        if case .date(let value) = self {
            return value
        }
        return nil
    }
    
    public var urlValue: URL? {
        if case .url(let value) = self {
            return value
        }
        return nil
    }
    
    public var arrayValue: [AnySendableValue]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }
    
    public var dictionaryValue: [String: AnySendableValue]? {
        if case .dictionary(let value) = self {
            return value
        }
        return nil
    }
}

extension Dictionary where Key == String, Value == Any {
    public var sendable: [String: AnySendableValue] {
        return self.mapValues(AnySendableValue.init)
    }
}

extension Dictionary where Key == String, Value == AnySendableValue {
    public var asAnyDictionary: [String: Any] {
        return self.mapValues(\.value)
    }
}