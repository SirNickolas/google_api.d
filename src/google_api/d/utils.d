module google_api.d.utils;

@safe:

///
inout(char)[ ] validateUtf(return scope inout(ubyte)[ ] data) pure {
    import std.utf: validate;

    inout result = cast(inout(char)[ ])data;
    result.validate();
    return result;
}

private template _concat(Args...) {
    import std.meta: Alias;

    alias capacity = Alias!0;
    static foreach (T; Args)
        static if (is(T == char))
            capacity = Alias!(capacity + 1);
        else static if (is(T == ubyte))
            capacity = Alias!(capacity + 3);
        else static if (is(T == byte))
            capacity = Alias!(capacity + 4);
        else static if (is(T == ushort) || is(T == bool))
            capacity = Alias!(capacity + 5);
        else static if (is(T == short))
            capacity = Alias!(capacity + 6);
        else static if (is(T == uint))
            capacity = Alias!(capacity + 10);
        else static if (is(T == int))
            capacity = Alias!(capacity + 11);
        else static if (is(T == ulong) || is(T == long))
            capacity = Alias!(capacity + 20);
        else
            static assert(is(T == char[ ]), "Unsupported type `", T, "`");

    char[ ] _concat(scope const Args args) nothrow pure {
        import std.array: uninitializedArray;
        import std.conv: toChars;

        size_t i = capacity;
        static foreach (j, T; Args)
            static if (is(T == char[ ]))
                i += args[j].length;

        auto result = uninitializedArray!(char[ ])(i);
        i = 0;
        static foreach (j, arg; args)
            static if (is(Args[j] == char[ ]))
                result[i .. i += arg.length] = arg;
            else static if (is(Args[j] == char))
                result[i++] = arg;
            else static if (is(Args[j] == bool))
                if (arg)
                    result[i .. i += 4] = "true";
                else
                    result[i .. i += 5] = "false";
            else {{
                static if (arg.sizeof < 4) {
                    static if (__traits(isUnsigned, arg))
                        uint arg = arg;
                    else
                        int arg = arg;
                }
                foreach (c; arg.toChars)
                    result[i++] = c;
            }}

        return result[0 .. i];
    }
}

///
pragma(inline, true)
char[ ] concat(Args...)(scope const Args args) nothrow pure {
    import std.meta: ReplaceAll;

    return _concat!(ReplaceAll!(string, char[ ], Args))(args);
}
