//
//  File.swift
//  
//
//  Created by Miguel de Icaza on 3/24/23.
//

import Foundation
@_implementationOnly import GDExtension

/// Variant objects box various Godot Objects, you create them with one of the
/// constructors, and you can retrieve the contents using the various extension
/// constructors that are declared on the various types that are wrapped.
///
/// You can retrieve the type of a variant from the ``gtype`` property.
///
/// A Variant takes up only 20 bytes and can store almost any engine datatype
/// inside of it. Variants are rarely used to hold information for long periods of
/// time. Instead, they are used mainly for communication, editing, serialization and
/// moving data around.
///
/// A Variant:
/// - Can store almost any Godot engine datatype.
/// - Can perform operations between many variants. GDScript uses Variant as its atomic/native datatype.
/// - Can be hashed, so it can be compared to other variants.
/// - Can be used to convert safely between datatypes.
/// - Can be used to abstract calling methods and their arguments. Godot exports all its functions through variants.
/// - Can be used to defer calls or move data between threads.
/// - Can be serialized as binary and stored to disk, or transferred via network.
/// - Can be serialized to text and use it for printing values and editable settings.
/// - Can work as an exported property, so the editor can edit it universally.
/// - Can be used for dictionaries, arrays, parsers, etc.
///
/// > Note: Containers (``GArray`` and ``Dictionary``): Both are implemented using variants.
/// A ``Dictionary`` can match any datatype used as key to any other datatype. An ``GArray`
/// just holds an array of Variants.  A ``Variant`` can also hold a ``Dictionary`` and an ``Array``
/// inside.
///
/// Modifications to a container will modify all references to it.

public class Variant: Hashable, Equatable, ExpressibleByStringLiteral {
    static var fromTypeMap: [GDExtensionVariantFromTypeConstructorFunc] = {
        var map: [GDExtensionVariantFromTypeConstructorFunc] = []
        
        for vtype in 0..<Variant.GType.max.rawValue {
            let v = UInt32 (vtype == 0 ? 1 : vtype)
            map.append (gi.get_variant_from_type_constructor (GDExtensionVariantType (v))!)
        }
        return map
    }()
    
    static var toTypeMap: [GDExtensionTypeFromVariantConstructorFunc] = {
        var map: [GDExtensionTypeFromVariantConstructorFunc] = []
        
        for vtype in 0..<Variant.GType.max.rawValue {
            let v = UInt32 (vtype == 0 ? 1 : vtype)
            map.append (gi.get_variant_to_type_constructor (GDExtensionVariantType (v))!)
        }
        return map
    }()
    
    typealias ContentType = (Int, Int, Int)
    var content: ContentType = (0, 0, 0)
    static var zero: ContentType = (0, 0, 0)
    
    /// Initializes from the raw contents of another Variant
    init (fromContent: ContentType) {
        content = fromContent
    }
    
    deinit {
        gi.variant_destroy (&content)
    }
    
    /// Creates a nil variant
    public init (_ value: Nil) {
        var nh: UnsafeMutableRawPointer?
        
        gi.variant_new_nil (UnsafeMutablePointer (&content))
    }
    
    public init () {
        var nh: UnsafeMutableRawPointer?
        
        gi.variant_new_nil (UnsafeMutablePointer (&content))
    }

    public static func == (lhs: Variant, rhs: Variant) -> Bool {
        var valid = GDExtensionBool (0)
        var ret = Variant (false)
        
        gi.variant_evaluate (GDEXTENSION_VARIANT_OP_EQUAL, &lhs.content, &rhs.content, &ret, &valid)
        return Bool (ret) ?? false
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(gi.variant_hash (&content))
    }
    
    public init (_ other: Variant) {
        var copy = other
        gi.variant_new_copy (&content, &copy.content)
    }
    
    public init (_ value: Bool) {
        var v = GDExtensionBool (value ? 1 : 0)
        Variant.fromTypeMap [GType.bool.rawValue] (&content, &v)
   }
    
    public init (_ value: Int) {
        var v = GDExtensionInt(value)
        Variant.fromTypeMap [GType.int.rawValue] (&content, &v)
    }

    public init (_ value: Int64) {
        var v = GDExtensionInt(Int(value))
        Variant.fromTypeMap [GType.int.rawValue] (&content, &v)
    }

    public init (_ value: String) {
        var vh: UnsafeMutableRawPointer?
        var v = GDExtensionStringPtr (mutating: value.cString(using: .utf8))
        Variant.fromTypeMap [GType.int.rawValue] (&content, &v)
    }
    
    public required init(stringLiteral: String) {
        var vh: UnsafeMutableRawPointer?
        var v = GDExtensionStringPtr (mutating: stringLiteral.cString(using: .utf8))
        Variant.fromTypeMap [GType.int.rawValue] (&content, &v)
    }

    public init (_ value: Float) {
        var v = Double (value)
        Variant.fromTypeMap [GType.float.rawValue] (&content, &v)
    }
    
    public init (_ value: GString) {
        var v = GDExtensionStringPtr (&value.content)
        Variant.fromTypeMap [GType.string.rawValue] (&content, v)
    }
    
    public init (_ value: Vector2) {
        var v = value
        Variant.fromTypeMap [GType.vector2.rawValue] (&content, &v)
    }
    
    public init (_ value: Vector2i) {
        var v = value
        Variant.fromTypeMap [GType.vector2i.rawValue] (&content, &v)
    }
    
    public init (_ value: Rect2) {
        var v = value
        Variant.fromTypeMap [GType.rect2.rawValue] (&content, &v)
    }
    
    public init (_ value: Rect2i) {
        var v = value
        Variant.fromTypeMap [GType.rect2i.rawValue] (&content, &v)
    }
    
    public init (_ value: Vector3) {
        var v = value
        Variant.fromTypeMap [GType.vector3.rawValue] (&content, &v)
    }
    
    public init (_ value: Vector3i) {
        var v = value
        Variant.fromTypeMap [GType.vector3i.rawValue] (&content, &v)
    }
    
    public init (_ value: Transform2D) {
        var v = value
        Variant.fromTypeMap [GType.transform2d.rawValue] (&content, &v)
    }
    
    public init (_ value: Vector4) {
        var v = value
        Variant.fromTypeMap [GType.vector4.rawValue] (&content, &v)
    }
    
    public init (_ value: Vector4i) {
        var v = value
        Variant.fromTypeMap [GType.vector4i.rawValue] (&content, &v)
    }
    
    public init (_ value: Plane) {
        var v = value
        Variant.fromTypeMap [GType.plane.rawValue] (&content, &v)
    }
    
    public init (_ value: Quaternion) {
        var v = value
        Variant.fromTypeMap [GType.quaternion.rawValue] (&content, &v)
    }
    
    public init (_ value: AABB) {
        var v = value
        Variant.fromTypeMap [GType.aabb.rawValue] (&content, &v)
    }
    
    public init (_ value: Basis) {
        var v = value
        Variant.fromTypeMap [GType.basis.rawValue] (&content, &v)
    }
    
    public init (_ value: Transform3D) {
        var v = value
        Variant.fromTypeMap [GType.transform3d.rawValue] (&content, &v)
    }
    
    public init (_ value: Projection) {
        var v = value
        Variant.fromTypeMap [GType.projection.rawValue] (&content, &v)
    }
    
    public init (_ value: Color) {
        var v = value
        Variant.fromTypeMap [GType.color.rawValue] (&content, &v)
    }
    
    public init (_ value: StringName) {
        Variant.fromTypeMap [GType.stringName.rawValue] (&content, &value.content)
    }
    
    public init (_ value: NodePath) {
        Variant.fromTypeMap [GType.nodePath.rawValue] (&content, &value.content)
    }
    
    public init (_ value: RID) {
        Variant.fromTypeMap [GType.rid.rawValue] (&content, &value.content)
    }
    
    public init (_ value: Object) {
        Variant.fromTypeMap [GType.object.rawValue] (&content, UnsafeMutableRawPointer (mutating: value.handle))
    }

    public init (_ value: Callable) {
        Variant.fromTypeMap [GType.callable.rawValue] (&content, &value.content)
    }
    
    public init (_ value: Signal) {
        Variant.fromTypeMap [GType.signal.rawValue] (&content, &value.content)
    }
    
    public init (_ value: Dictionary) {
        Variant.fromTypeMap [GType.dictionary.rawValue] (&content, &value.content)
    }
    
    public init (_ value: GArray) {
        Variant.fromTypeMap [GType.array.rawValue] (&content, &value.content)
    }
    
    public init (_ value: PackedByteArray) {
        Variant.fromTypeMap [GType.packedByteArray.rawValue] (&content, &value.content)
    }
    
    public init (_ value: PackedInt32Array) {
        Variant.fromTypeMap [GType.packedInt32Array.rawValue] (&content, &value.content)
    }
    
    public init (_ value: PackedInt64Array) {
        Variant.fromTypeMap [GType.packedInt64Array.rawValue] (&content, &value.content)
    }
    
    public init (_ value: PackedFloat32Array) {
        Variant.fromTypeMap [GType.packedFloat32Array.rawValue] (&content, &value.content)
    }
    
    public init (_ value: PackedFloat64Array) {
        Variant.fromTypeMap [GType.packedFloat64Array.rawValue] (&content, &value.content)
    }
    
    public init (_ value: PackedStringArray) {
        Variant.fromTypeMap [GType.packedStringArray.rawValue] (&content, &value.content)
    }
    
    public init (_ value: PackedVector2Array) {
        Variant.fromTypeMap [GType.packedVector2Array.rawValue] (&content, &value.content)
    }
    
    public init (_ value: PackedVector3Array) {
        Variant.fromTypeMap [GType.packedVector3Array.rawValue] (&content, &value.content)
    }
    
    public init (_ value: PackedColorArray) {
        Variant.fromTypeMap [GType.packedColorArray.rawValue] (&content, &value.content)
    }
    
    public var gtype: GType {
        var copy = content
        return GType (rawValue: Int (gi.variant_get_type (&copy).rawValue)) ?? .nil
    }
    
    func toType (_ type: GType, dest: UnsafeMutableRawPointer) {
        Variant.toTypeMap [type.rawValue] (dest, &content)
    }
    
    public var description: String {
        var ret = GDExtensionStringPtr (bitPattern: 0)
        gi.variant_stringify (&content, &ret)
        if let ret = OpaquePointer(ret) {
            let str = stringFromGodotString(UnsafeRawPointer (ret))
            GString.destructor (UnsafeMutableRawPointer (ret))
            return str ?? ""
        } else {
            return ""
        }
    }
}

extension Int: GodotVariant {
    /// Creates a new instance from the given variant if it contains an integer
    public init? (_ from: Variant) {
        guard from.gtype == .int else {
            return nil
        }
        var value = 0
        from.toType(.int, dest: &value)
        self.init (value)
    }
    
    public func toVariant () -> Variant { Variant (self) }
}

extension Int64: GodotVariant {
    /// Creates a new instance from the given variant if it contains an integer
    public init? (_ from: Variant) {
        guard from.gtype == .int else {
            return nil
        }
        var value = 0
        from.toType(.int, dest: &value)
        self.init (value)
    }
    
    public func toVariant () -> Variant { Variant (Int (self)) }
}

extension Bool: GodotVariant {
    /// Creates a new instance from the given variant if it contains a boolean
    public init? (_ from: Variant) {
        guard from.gtype == .bool else {
            return nil
        }
        var v = GDExtensionBool (0)
        from.toType(.bool, dest: &v)
        self.init (v == 0 ? false : true)
    }
    
    public func toVariant () -> Variant { Variant (self) }
}

extension Float: GodotVariant {
    /// Creates a new instance from the given variant if it contains a float
    public init? (_ from: Variant) {
        guard from.gtype == .float else {
            return nil
        }
        var value: Float = 0
        from.toType(.float, dest: &value)
        self.init (value)
    }

    public func toVariant () -> Variant { Variant (self) }
}

extension Double {
    /// Creates a new instance from the given variant if it contains a float
    public init? (_ from: Variant) {
        guard from.gtype == .float else {
            return nil
        }
        var value: Float = 0
        from.toType(.float, dest: &value)
        self.init (Double (value))
    }
}

