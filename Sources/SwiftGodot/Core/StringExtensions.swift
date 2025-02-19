//
//  File.swift
//  
//
//  Created by Miguel de Icaza on 3/26/23.
//

import Foundation
@_implementationOnly import GDExtension

extension StringName {
    /// Creates a StringName from a Swift String
    public convenience init (_ from: String) {
        self.init (from: from)
    }
    
    /// Returns a Swift string from the StringName
    public var description: String {
        let buffer = toUtf8Buffer()
        return buffer.getStringFromUtf8().description
    }
    
    /// Compares two StringNames for equality.
    public static func == (lhs: StringName, rhs: StringName) -> Bool {
        lhs.content == rhs.content
    }
}

// TODO make sure we release
func stringToGodotHandle (_ str: String) -> GDExtensionStringPtr {
    var ret = GDExtensionStringPtr (bitPattern: 0)
    gi.string_new_with_utf8_chars (&ret, str)
    return ret!
}

func stringFromGodotString (_ ptr: UnsafeRawPointer) -> String? {
    let n = gi.string_to_utf8_chars (ptr, nil, 0)
    return withUnsafeTemporaryAllocation (of: UInt8.self, capacity: Int (n)) { ptr in String (bytes: ptr, encoding: .utf8) }
}
    
extension GString {
    /// Returns a Swift string from a pointer to a native Godot string
    static func stringFromGStringPtr (ptr: UnsafeRawPointer?) -> String? {
        guard let ptr else {
            return nil
        }
        var content = GString.zero
        let len = gi.string_to_utf8_chars (UnsafeMutableRawPointer (mutating: ptr), nil, 0)
        return withUnsafeTemporaryAllocation(byteCount: Int(len+1), alignment: 4) { strPtr in
            gi.string_to_utf8_chars (UnsafeMutableRawPointer (mutating: ptr), strPtr.baseAddress, len)
            strPtr [Int (len)] = 0
            return String (cString: strPtr.assumingMemoryBound(to: UInt8.self).baseAddress!)
        }
    }
    
    /// Returns a Swift string from this GString.
    public var description: String {
        get {
            let len = gi.string_to_utf8_chars (UnsafeRawPointer (&content), nil, 0)
            return withUnsafeTemporaryAllocation(byteCount: Int(len+1), alignment: 4) { strPtr in
                gi.string_to_utf8_chars (UnsafeRawPointer (&content), strPtr.baseAddress, len)
                strPtr [Int (len)] = 0
                return String (cString: strPtr.assumingMemoryBound(to: UInt8.self).baseAddress!)
            } ?? ""
        }
    }
    
}

extension String: GodotVariant {
    static func pointer(_ object: AnyObject?) -> String {
        guard let object = object else { return "nil" }
        let opaque: UnsafeMutableRawPointer = Unmanaged.passUnretained(object).toOpaque()
        return String(describing: opaque)
    }
    
    public func toVariant () -> Variant {
        return Variant (self)
    }
    
    public init (_ n: StringName) {
        self = n.description
    }
    
    public init? (_ fromVariant: Variant) {
        guard fromVariant.gtype == .string else {
            return nil
        }
        var content = GString.zero
        
        fromVariant.toType(.string, dest: &content)
        let g = GString(content: content)
        self = g.description
    }
}
