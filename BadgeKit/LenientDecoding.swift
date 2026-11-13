/// Reading settings that another MenuBadge version wrote: values this one cannot read are skipped
/// instead of failing the whole settings blob.
extension KeyedDecodingContainer {
    /// The value for `key`, or nil when it is missing or cannot be read as `T`.
    func lenient<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        try? decodeIfPresent(type, forKey: key)
    }
}

/// An array element that decodes to nil instead of failing the whole array.
struct Lenient<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}
