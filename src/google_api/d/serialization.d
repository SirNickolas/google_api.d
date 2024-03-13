module google_api.d.serialization;

public import google_api.d.buffer; ///

nothrow pure @safe:

/// Like `std.uri.encodeComponent` but does not perform pointless allocations.
void serializeToUrl(scope ref Buffer b, scope const(char)[ ] s) {
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

package(google_api) immutable string[2] boolMemberNames = ["false", "true"];

package(google_api) string extract(scope ref Buffer b) {
    immutable s = b.dupData();
    b.clear();
    return s;
}

package(google_api) bool finishJsonObject(scope ref Buffer b, char s) {
    if (s == ',') {
        b ~= '}';
        return true;
    }
    b ~= "{}";
    return false;
}