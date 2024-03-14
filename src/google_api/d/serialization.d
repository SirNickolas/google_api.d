module google_api.d.serialization;

public import google_api.d.buffer; ///

import vibe.data.json: Json;

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

immutable string[2] boolMemberNames = ["false", "true"];

void finishJsonArray(scope ref Buffer b, char s) nothrow pure {
    if (s == ',')
        b ~= ']';
    else
        b ~= "[]";
}

bool finishJsonObject(scope ref Buffer b, char s) nothrow pure {
    if (s == ',') {
        b ~= '}';
        return true;
    }
    b ~= "{}";
    return false;
}

enum isPrimitiveJsonType(T) =
    is(T == bool) || is(T == int) || is(T == uint) || is(T == float) || is(T == double) ||
    is(immutable T == immutable char[ ]) || is(T == Json) ||
    ((is(T == U[ ], U) || is(T == U[string], U)) && isPrimitiveJsonType!U);

enum isLongJsonType(T) = is(typeof({ Buffer b; b.serializeLongAsJson(T.init); }));

@property bool isUndefined(scope ref const Json j) nothrow /+pure+/ @trusted /+@nogc+/ {
    return j.type == Json.Type.undefined; // `@trusted` because of `scope`.
}

/// Serialization for the polymorphic `Json` type. Forwards to `vibe.data.json`.
void serializeAsJson(scope ref Buffer b, scope ref const Json x) /+pure+/ @trusted {
    import vibe.data.json: writeJsonString;

    writeJsonString(b.sink, x); // `@trusted` because of `scope`.
}

/// Serialization for primitive types, arrays, and AAs of them. Forwards to `vibe.data.json`.
void serializeAsJson(T)(scope ref Buffer b, scope const T x) /+pure+/ @trusted
if (isPrimitiveJsonType!T) {
    import vibe.data.json: serializeToJson;

    serializeToJson(b.sink, x); // `@trusted` because of `scope`.
}

/// Serialization for `long` and `ulong`. They are represented as strings in Google APIs.
// TODO: Deserialization needs to be adjusted, too, perhaps via a policy.
void serializeLongAsJson(T)(scope ref Buffer b, const T x) nothrow pure
if (is(T == long) || is(T == ulong)) {
    import std.conv: toChars;

    b ~= '"';
    put(b.sink, x.toChars);
    b ~= '"';
}

/// ditto
void serializeLongAsJson(T)(scope ref Buffer b, scope const T[ ] a) pure
if (isLongJsonType!T) {
    char s = '[';
    foreach (x; a) {
        b ~= s;
        b.serializeLongAsJson(x);
        s = ',';
    }
    b.finishJsonArray(s);
}

/// ditto
void serializeLongAsJson(T)(scope ref Buffer b, scope const T[string] aa) pure
if (isLongJsonType!T) {
    char s = '{';
    foreach (k, v; aa) {
        b ~= s;
        b.serializeAsJson(k);
        b ~= ':';
        b.serializeLongAsJson(v);
        s = ',';
    }
    b.finishJsonObject(s);
}

/// ditto
alias serializeAsJson = serializeLongAsJson;

/// Serialization for arrays and AAs whose elements are not primitive.
template jsonSerializersForContainers() {
    void serializeAsJson(T)(scope ref Buffer b, scope const T[ ] a)
    if (!is(immutable T == immutable char) && !isPrimitiveJsonType!T && !isLongJsonType!T) {
        char s = '[';
        foreach (ref x; a) {
            b ~= s;
            .serializeAsJson(b, x);
            s = ',';
        }
        b.finishJsonArray(s);
    }

    void serializeAsJson(T)(scope ref Buffer b, scope const T[string] aa)
    if (!isPrimitiveJsonType!T && !isLongJsonType!T) {
        char s = '{';
        foreach (k, ref v; aa) {
            b ~= s;
            .serializeAsJson(b, k);
            b ~= ':';
            .serializeAsJson(b, v);
            s = ',';
        }
        b.finishJsonObject(s);
    }
}
