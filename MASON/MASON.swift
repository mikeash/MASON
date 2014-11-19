
import Foundation

public class MASONObject {
    public struct Error {
        public enum Element: Equatable {
            case Index(Int)
            case Key(String)
        }
        
        public let keyPath: [Element]
        public let expectedTypeName: String
        public let actualTypeName: String
    }
    
    
    let underlyingValue: AnyObject?
    
    public private(set) var errors = [Error]()
    
    let keyPath: [Error.Element]
    
    let parent: MASONObject?
    
    public init(underlyingValue: AnyObject?, keyPath: [Error.Element], parent: MASONObject?) {
        self.underlyingValue = underlyingValue
        self.keyPath = keyPath
        self.parent = parent
    }
    
    public convenience init(_ underlyingValue: AnyObject?) {
        self.init(underlyingValue: underlyingValue, keyPath: [], parent: nil)
    }
    
    func get<T>(typename: String) -> T? {
        if let typedValue = underlyingValue as? T {
            return typedValue
        } else {
            let typeName = underlyingValue.map{ NSStringFromClass($0.classForCoder) }
            let error = Error(keyPath: keyPath, expectedTypeName: typename, actualTypeName: typeName ?? "nil")
            addError(error)
            return nil
        }
    }
    
    func addError(error: Error) {
        errors.append(error)
        parent?.addError(error)
    }
    
    public var string: String {
        return get("string") ?? ""
    }
    
    public var double: Double {
        return get("number") ?? 0.0
    }
    
    public var dict: MASONDictionary {
        if let dict: NSDictionary = get("dictionary") {
            return MASONDictionary(parent: self, dict: dict)
        } else {
            return MASONDictionary(parent: nil, dict: [:])
        }
    }
    
    public var array: MASONArray {
        if let array: NSArray = get("array") {
            return MASONArray(parent: self, array: array)
        } else {
            return MASONArray(parent: nil, array: [])
        }
    }
}

public struct MASONDictionary {
    let parent: MASONObject?
    let dict: NSDictionary
    
    public subscript(key: String) -> MASONObject {
        let keyPath = (parent?.keyPath ?? []) + [.Key(key)]
        return MASONObject(underlyingValue: dict[key], keyPath: keyPath, parent: parent)
    }
}

public struct MASONArray {
    let parent: MASONObject?
    let array: NSArray
    
    public subscript(key: Int) -> MASONObject {
        let value: AnyObject? = key < array.count ? array[key] : nil
        let keyPath = (parent?.keyPath ?? []) + [.Index(key)]
        return MASONObject(underlyingValue: value, keyPath: keyPath, parent: parent)
    }
    
    public func map<T>(f: MASONObject -> T) -> [T] {
        var results = [T]()
        for i in 0 ..< array.count {
            results.append(f(self[i]))
        }
        return results
    }
}

public func ==(a: MASONObject.Error.Element, b: MASONObject.Error.Element) -> Bool {
    switch (a, b) {
    case let (.Index(aIndex), .Index(bIndex)):
        return aIndex == bIndex
    case let(.Key(aKey), .Key(bKey)):
        return aKey == bKey
    default:
        return false
    }
}

public func Decode<T>(json: AnyObject?, f: MASONObject -> T) -> (T?, [MASONObject.Error]?) {
    let obj = MASONObject(json)
    let result = f(obj)
    if obj.errors.count == 0 {
        return (result, nil)
    } else {
        return (nil, obj.errors)
    }
}
