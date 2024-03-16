module google_api.d.serialization;

public import google_api.d.buffer; ///

import std.meta: AliasSeq;
import std.typecons: Nullable, Ternary;
import vibe.data.json: Json;
import google_api.d.utils: ForceConst;

package(google_api) @safe:

/// Like `std.uri.encodeComponent` but does not perform pointless allocations.
public void serializeAsUrl(scope ref Buffer b, scope const(char)[ ] s) nothrow pure {
    enum hex = "0123456789ABCDEF";
    foreach (c; s)
        switch (c) {
        case 'A': .. case 'Z':
        case 'a': .. case 'z':
        case '0': .. case '9':
        case '-', '_', '.', '!', '~', '*', '\'', '(', ')':
            b ~= c;
            break;

        default:
            b ~= '%';
            b ~= hex[c >> 4];
            b ~= hex[c & 0x0F];
        }
}

string extract(scope ref Buffer b) nothrow pure {
    immutable s = b.dupData();
    b.clear();
    return s;
}

private immutable string[2] _boolMemberNames = ["false", "true"];

private void _finishArray(char sep, scope ref Buffer b) nothrow pure {
    if (sep == ',')
        b ~= ']';
    else
        b ~= "[]";
}

bool finish(char sep, scope ref Buffer b) nothrow pure {
    if (sep == ',') {
        b ~= '}';
        return true;
    }
    b ~= "{}";
    return false;
}

private enum _isPrimitiveJsonType(T: const T) =
    is(T == bool) || is(T == int) || is(T == uint) || is(T == float) || is(T == double) ||
    is(T == const(char)[ ]) || is(T == Json) ||
    ((is(T == U[ ], U) || is(T == U[string], U)) && _isPrimitiveJsonType!U);

private void _serializePrimitive(T: const T)(scope ref Buffer b, scope ref const T x)
/+pure+/ @trusted if (is(T == Json)) {
    import vibe.data.json: writeJsonString;

    writeJsonString(b.sink, x); // `@trusted` because of `scope`.
}

private void _serializePrimitive(T: const T)(scope ref Buffer b, scope const T x) /+pure+/ @trusted
if (_isPrimitiveJsonType!T) {
    import vibe.data.json: serializeToJson;

    serializeToJson(b.sink, x); // `@trusted` because of `scope`.
}

private void _serializeArray(alias serializer, T)(scope ref Buffer b, scope const T[ ] a) /+pure+/ {
    char sep = '[';
    foreach (x; a) {
        b ~= sep;
        serializer(b, x);
        sep = ',';
    }
    sep._finishArray(b);
}

private void _serializeAa(alias serializer, T)(scope ref Buffer b, scope const T[string] aa)
/+pure+/ {
    char sep = '{';
    foreach (k, v; aa) {
        b ~= sep;
        b._serializePrimitive!(const(char)[ ])(k);
        b ~= ':';
        serializer(b, v);
        sep = ',';
    }
    sep.finish(b);
}

// TODO: Deserialization needs to be adjusted, too, perhaps via a policy.
private template _serializeLong(T: const T) {
    static if (is(T == U[ ], U))
        alias _serializeLong = _serializeArray!(_serializeLong!U, U);
    else static if (is(T == U[string], U))
        alias _serializeLong = _serializeAa!(_serializeLong!U, U);
    else {
        static assert(is(T == long) || is(T == ulong));

        void _serializeLong(scope ref Buffer b, T value) nothrow pure {
            import std.conv: toChars;

            b ~= '"';
            put(b.sink, value.toChars);
            b ~= '"';
        }
    }
}

private template _serializeTrivial(T) {
    static if (_isPrimitiveJsonType!T)
        alias _serializeTrivial = _serializePrimitive!T;
    else
        alias _serializeTrivial = _serializeLong!T;
}

private template _serializeCustom(alias ns, T: const T) {
    static if (is(T == struct))
        alias _serializeCustom = ns.serializeAsJson;
    else static if (is(T == U[ ], U))
        alias _serializeCustom = _serializeArray!(._serializeCustom!(ns, U), U);
    else static if (is(T == U[string], U))
        alias _serializeCustom = _serializeAa!(._serializeCustom!(ns, U), U);
    else {
        static assert(is(T == enum));

        void _serializeCustom(scope ref Buffer b, T value) nothrow pure {
            b ~= '"';
            b ~= ns.enumMemberNames[value];
            b ~= '"';
        }
    }
}

/// Serialization for the boolean type.
char addB(char sep, scope ref Buffer b, scope const(char)[ ] prefixAndValue, bool value)
nothrow pure {
    if (!value)
        return sep;
    b ~= sep;
    b ~= prefixAndValue;
    return ',';
}

/// ditto
char add(char sep, scope ref Buffer b, scope const(char)[ ] prefix, Ternary value) nothrow pure {
    if (value == Ternary.unknown)
        return sep;
    b ~= sep;
    b ~= prefix;
    b ~= _boolMemberNames[value != Ternary.no];
    return ',';
}

/// Serialization for integral types (`long` and `ulong` are represented as strings).
static foreach (T; AliasSeq!(int, uint, long, ulong))
char add(char sep, scope ref Buffer b, scope const(char)[ ] prefix, T value, T def = 0)
nothrow pure {
    import std.conv: toChars;

    if (value == def)
        return sep;
    b ~= sep;
    b ~= prefix;
    static if (T.sizeof > 4)
        b ~= '"';
    put(b.sink, value.toChars);
    static if (T.sizeof > 4)
        b ~= '"';
    return ',';
}

/// Serialization for floating-point types.
char add(char sep, scope ref Buffer b, scope const(char)[ ] prefix, double value) /+pure+/ {
    import std.math.traits: isNaN;

    if (value.isNaN)
        return sep;
    b ~= sep;
    b ~= prefix;
    b._serializePrimitive(value);
    return ',';
}

private @property bool _isUndefined(scope ref const Json j) nothrow /+pure+/ @trusted /+@nogc+/ {
    return j.type == Json.Type.undefined; // `@trusted` because of `scope`.
}

/// Serialization for embbedded JSON.
char add(char sep, scope ref Buffer b, scope const(char)[ ] prefix, scope ref const Json value)
/+pure+/ {
    if (value._isUndefined)
        return sep;
    b ~= sep;
    b ~= prefix;
    b._serializePrimitive(value);
    return ',';
}

/// Serialization for strings with an explicit default value.
char add(
    char sep,
    scope ref Buffer b,
    scope const(char)[ ] prefix,
    scope const(char)[ ] value,
    scope const(char)[ ] def,
) /+pure+/ {
    if (value == def)
        return sep;
    b ~= sep;
    b ~= prefix;
    b._serializePrimitive(value);
    return ',';
}

/// Serialization for `Nullable!T` where `T` is a trivial JSON type.
char add(T)(
    char sep, scope ref Buffer b, scope const(char)[ ] prefix, scope ref const Nullable!T value,
) /+pure+/ {
    if (value.isNull)
        return sep;
    b ~= sep;
    b ~= prefix;
    b._serializeTrivial!(ForceConst!T)(value.get);
    return ',';
}

/// Serialization for arrays and AAs of `T` (including strings) where T is a trivial JSON type.
char add(A)(char sep, scope ref Buffer b, scope const(char)[ ] prefix, scope const A value) /+pure+/
if (is(A == T[ ], T) || is(A == T[string], T)) {
    if (!value.length)
        return sep;
    b ~= sep;
    b ~= prefix;
    b._serializeTrivial!(ForceConst!A)(value);
    return ',';
}

/// Serialization for `Nullable!T` where `T` is a custom type.
char add(alias ns, T)(
    char sep, scope ref Buffer b, scope const(char)[ ] prefix, scope ref const Nullable!T value,
) /+pure+/ {
    if (value.isNull)
        return sep;
    b ~= sep;
    b ~= prefix;
    b._serializeCustom!(ns, ForceConst!T)(value.get);
    return ',';
}

/// Serialization for arrays and AAs of `T` where `T` is a custom type.
char add(alias ns, A)(
    char sep, scope ref Buffer b, scope const(char)[ ] prefix, scope const A value,
) /+pure+/ if (is(A == T[ ], T) || is(A == T[string], T)) {
    if (!value.length)
        return sep;
    b ~= sep;
    b ~= prefix;
    b._serializeCustom!(ns, ForceConst!A)(value);
    return ',';
}

/// Serialization for enums.
char add(alias ns, E)(
    char sep, scope ref Buffer b, scope const(char)[ ] prefix, const E value, const E def = E.init,
) nothrow pure if (is(E == enum)) {
    if (value == def)
        return sep;
    b ~= sep;
    b ~= prefix;
    b ~= '"';
    b ~= ns.enumMemberNames[value];
    b ~= '"';
    return ',';
}

/// Serialization for structs.
char add(alias ns, T)(
    char sep, scope ref Buffer b, scope const(char)[ ] prefix, scope ref const T value,
) /+pure+/ if (is(T == struct)) {
    const mark = b.mark;
    b ~= sep;
    b ~= prefix;
    if (ns.serializeAsJson(b, value))
        return ',';
    b.reset(mark);
    return sep;
}
