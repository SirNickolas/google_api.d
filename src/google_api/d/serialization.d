module google_api.d.serialization;

public import google_api.d.buffer; ///

package(google_api) nothrow pure @safe:

/// Like `std.uri.encodeComponent` but does not perform pointless allocations.
public void serializeAsUrl(scope ref Buffer b, scope const(char)[ ] s) {
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

immutable string[2] boolMemberNames = ["false", "true"];

string extract(scope ref Buffer b) {
    immutable s = b.dupData();
    b.clear();
    return s;
}

bool finishJsonArray(scope ref Buffer b, char s) {
    if (s == ',') {
        b ~= ']';
        return true;
    }
    b ~= "[]";
    return false;
}

bool finishJsonObject(scope ref Buffer b, char s) {
    if (s == ',') {
        b ~= '}';
        return true;
    }
    b ~= "{}";
    return false;
}

template jsonSerializersForContainers() {
    bool serializeAsJson(T)(scope ref Buffer b, scope const(T)[ ] a) {
        char s = '[';
        foreach (ref x; a) {
            b ~= s;
            .serializeAsJson(b, x);
            s = ',';
        }
        return b.finishJsonArray(s);
    }

    bool serializeAsJson(T)(scope ref Buffer b, scope const T[string] aa) {
        char s = '{';
        try
            foreach (k, ref v; aa) {
                b ~= s;
                serializeToJsonString(b.sink, k);
                b ~= ':';
                .serializeAsJson(b, v);
                s = ',';
            }
        catch (Exception e)
            assert(false, e.msg);
        return b.finishJsonObject(s);
    }
}
