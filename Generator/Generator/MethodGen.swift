//
//  MethodGen.swift
//  Generator
//
//  Created by Miguel de Icaza on 5/15/23.
//

import Foundation

enum MethodGenType {
    case `class`
    case `utility`
}
/// Generates a method definition
/// - Parameters:
///  - p: Our printer to generate the method
///  - method: the definition to generate
///  - className: the name of the class where this is being generated
///  - usedMethods: a set of methods that have been referenced by properties, to determine whether we make this public or private
/// - Returns: nil, or the method we surfaced that needs to have the virtual supporting infrastructured wired up
func methodGen (_ p: Printer, method: MethodDefinition, className: String, cdef: JClassInfo?, docClass: DocClass?, usedMethods: Set<String>, kind: MethodGenType) -> String? {
    var registerVirtualMethodName: String? = nil
    
    //let loc = "\(cdef.name).\(method.name)"
    if (method.arguments ?? []).contains(where: { $0.type.contains("*")}) {
        //print ("TODO: do not currently have support for C pointer types \(loc)")
        return nil
    }
    if method.returnValue?.type.firstIndex(of: "*") != nil {
        //print ("TODO: do not currently support C pointer returns \(loc)")
        return nil
    }
    let bindName = "method_\(method.name)"
    
    var visibility: String
    var eliminate: String
    var finalp: String
    // Default method name
    var methodName: String = godotMethodToSwift (method.name)
    
    let instanceOrStatic = method.isStatic ? " static" : ""
    var inline = ""
    if let methodHash = method.hash {
        assert (!method.isVirtual)
        switch kind {
        case .class:
            p ("static var \(bindName): GDExtensionMethodBindPtr =", suffix: "()") {
                p ("let methodName = StringName (\"\(method.name)\")")
                
                p ("return gi.classdb_get_method_bind (UnsafeRawPointer (&\(className).className.content), UnsafeRawPointer (&methodName.content), \(methodHash))!")
            }
        case .utility:
            p ("static var \(bindName): GDExtensionPtrUtilityFunction =", suffix: "()") {
                p ("let methodName = StringName (\"\(method.name)\")")
                
                p ("return gi.variant_get_ptr_utility_function (UnsafeRawPointer (&methodName.content), \(methodHash))!")
            }
        }
        
        // If this is an internal, and being reference by a property, hide it
        if usedMethods.contains (method.name) {
            inline = "@inline(__always)"
            visibility = "internal"
            eliminate = "_ "
            methodName = method.name
        } else {
            visibility = "public"
            eliminate = ""
        }
        if instanceOrStatic == "" {
            finalp = "final "
        } else {
            finalp = ""
        }
    } else {
        assert (method.isVirtual)
        // virtual overwrittable method
        finalp = ""
        visibility = "@_documentation(visibility: public)\nopen"
        eliminate = ""
            
        registerVirtualMethodName = methodName
    }
    
    var args = ""
    var argSetup = ""
    var varArgSetup = ""
    var varArgSetupInit = ""
    if method.isVararg {
        varArgSetupInit = "\nvar varArgCopies: [Variant] = []\n"
        varArgSetup += "for varg in arguments {\n"
        varArgSetup += "    let copy = Variant (varg)\n"
        varArgSetup += "    varArgCopies.append (copy)\n"
        varArgSetup += "    args.append (&copy.content)\n"
        varArgSetup += "}\n"
    }

    if let margs = method.arguments {
        for arg in margs {
            if args != "" { args += ", " }
            args += getArgumentDeclaration(arg, eliminate: eliminate)
            var reference = escapeSwift (snakeToCamel (arg.name))

            if method.isVararg {
                argSetup += "var copy_\(arg.name) = Variant (\(reference))\n"
            } else if arg.type == "String" {
                argSetup += "var gstr_\(arg.name) = GString (\(reference))\n"
            } else if argTypeNeedsCopy(godotType: arg.type) {
                // Wrap in an Int
                if arg.type.starts(with: "enum::") {
                    reference = "Int64 (\(reference).rawValue)"
                }
                if isSmallInt (arg) {
                    argSetup += "var copy_\(arg.name): Int = Int (\(reference))\n"
                } else {
                    argSetup += "var copy_\(arg.name) = \(reference)\n"
                }
            }
        }
        if method.isVararg {
            if args != "" { args += ", "}
            args += "_ arguments: Variant..."
        }
        argSetup += "var args: [UnsafeRawPointer?] = [\n"
        for arg in margs {
            // When we move from GString to String in the public API
            //                if arg.type == "String" {
            //                    argSetup += "stringToGodotHandle (\(arg.name))\n"
            //                } else
            //                {
            var argref: String
            var optstorage: String
            var needAddress = "&"
            if method.isVararg {
                argref = "copy_\(arg.name)"
                optstorage = ".content"
            } else if arg.type == "String" {
                argref = "gstr_\(arg.name)"
                optstorage = ".content"
            } else if argTypeNeedsCopy(godotType: arg.type) {
                argref = "copy_\(arg.name)"
                optstorage = ""
            } else {
                argref = escapeSwift (snakeToCamel (arg.name))
                if isStructMap [arg.type] ?? false {
                    optstorage = ""
                } else {
                    if builtinSizes [arg.type] != nil && arg.type != "Object" || arg.type.starts(with: "typedarray::"){
                        optstorage = ".content"
                    } else {
                        optstorage = ".handle"
                        // No need to take the address for handles
                        needAddress = ""
                    }
                }
            }
            argSetup += "    UnsafeRawPointer(\(needAddress)\(escapeSwift(argref))\(optstorage)),"
            //                }
        }
        argSetup += "]"
        argSetup += varArgSetupInit
        argSetup += varArgSetup
    } else if method.isVararg {
        // No regular arguments, check if these are varargs
        if method.isVararg {
            args = "_ arguments: Variant..."
        }
        argSetup += "var args: [UnsafeRawPointer?] = []\n"
        argSetup += varArgSetupInit
        argSetup += varArgSetup
    }
    
    let godotReturnType = method.returnValue?.type
    let returnType = getGodotType (method.returnValue)
    
    if inline != "" {
        p (inline)
    }

    if let docClass, let methods = docClass.methods {
        if let docMethod = methods.method.first(where: { $0.name == method.name }) {
            doc (p, cdef, docMethod.description)
            // Sadly, the parameters have no useful documentation
        }
    }
    // Generate the method entry point
    if (discardableResultList [className]?.contains(method.name)) != nil {
        p ("@discardableResult")
    }
    p ("\(visibility)\(instanceOrStatic) \(finalp)func \(methodName) (\(args))\(returnType != "" ? "-> " + returnType : "")") {
        if method.hash == nil {
            if let godotReturnType {
                p (makeDefaultReturn (godotType: godotReturnType))
            }
        } else {
            var frameworkType = false
            if returnType != "" {
                if method.isVararg {
                    p ("var _result: Variant.ContentType = Variant.zero")
                } else if godotReturnType?.starts(with: "typedarray::") ?? false {
                    let (storage, initialize) = getBuiltinStorage ("Array")
                    p ("var _result: \(storage)\(initialize)")
                } else if godotReturnType == "String" {
                    p ("var _result = GString ()")
                } else {
                    if classMap [godotReturnType ?? ""] != nil {
                        frameworkType = true
                        p ("var _result = UnsafeRawPointer (bitPattern: 0)")
                    } else {
                        if godotReturnType!.starts(with: "enum::") {
                            p ("var _result: Int = 0 // to avoid packed enums on the stack")
                        } else {
                            p ("var _result: \(returnType) = \(makeDefaultInit(godotType: godotReturnType ?? ""))")
                        }
                    }
                }
            }
            
            if argSetup != "" {
                p (argSetup)
            }
            let ptrArgs = (args != "") ? "&args" : "nil"
            let ptrResult: String
            if returnType != "" {
                if argTypeNeedsCopy(godotType: godotReturnType!) {
                    ptrResult = "&_result"
                } else {
                    if godotReturnType!.starts (with: "typedarray::") {
                        ptrResult = "&_result"
                    } else if frameworkType {
                        ptrResult = "&_result"
                    } else if builtinSizes [godotReturnType!] != nil {
                        // a built-in struct or a class
                        if method.isVararg {
                            ptrResult = "&_result"
                        } else {
                            ptrResult = "&_result.content"
                        }
                    } else {
                        ptrResult = "&_result.handle"
                    }
                }
            } else {
                ptrResult = "nil"
            }
            
            switch kind {
            case .class:
                let instanceHandle = method.isStatic ? "nil, " : "UnsafeMutableRawPointer (mutating: handle), "
                if method.isVararg {
                    p ("gi.object_method_bind_call (\(className).method_\(method.name), \(instanceHandle)\(ptrArgs), Int64 (args.count), \(ptrResult), nil)")
                } else {
                    p ("gi.object_method_bind_ptrcall (\(className).method_\(method.name), \(instanceHandle)\(ptrArgs), \(ptrResult))")
                }
            case .utility:
                if method.isVararg {
                    p ("\(bindName) (\(ptrResult), \(ptrArgs), Int32 (args.count))")
                } else {
                    p ("\(bindName) (\(ptrResult), \(ptrArgs), Int32 (\(method.arguments?.count ?? 0)))")
                }
            }
            
            if returnType != "" {
                if method.isVararg {
                    if returnType == "Variant" {
                        p ("return Variant (fromContent: _result)")
                    } else if returnType == "GodotError" {
                        p ("return GodotError (rawValue: Int (Variant (fromContent: _result))!)!")
                    } else if returnType == "String" {
                        p ("return GString (Variant (fromContent: _result))?.description ?? \"\"")
                    } else {
                        fatalError("Do not support this return type")
                    }
                } else if frameworkType {
                    p ("return lookupObject (nativeHandle: _result!)")
                } else if godotReturnType?.starts(with: "typedarray::") ?? false {
                    let defaultInit = makeDefaultInit(godotType: godotReturnType!, initCollection: "content: _result")
                    
                    p ("return \(defaultInit)")
                } else if godotReturnType!.starts(with: "enum::"){
                    p ("return \(returnType) (rawValue: _result)!")
                } else if godotReturnType == "String" {
                    p ("return _result.description")
                } else {
                    p ("return _result")
                }
            }
        }
    }
    return registerVirtualMethodName
}
