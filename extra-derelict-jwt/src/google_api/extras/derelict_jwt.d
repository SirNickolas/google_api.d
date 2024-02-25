module google_api.extras.derelict_jwt;

///
public import derelict.jwt.jwt: DerelictJWT;
///
public import derelict.jwt.jwttypes:
    JWT_ALG_NONE,
    JWT_ALG_HS256, JWT_ALG_HS384, JWT_ALG_HS512,
    JWT_ALG_RS256, JWT_ALG_RS384, JWT_ALG_RS512,
    JWT_ALG_ES256, JWT_ALG_ES384, JWT_ALG_ES512;

@safe:

pragma(inline, false)
private noreturn _throwErrno(int code, string msg, string file, size_t line) {
    import std.exception: ErrnoException;

    throw new ErrnoException(msg, code, file, line);
}

pragma(inline, true)
private void _enforce0(int code, string msg, string file = __FILE__, size_t line = __LINE__) {
    if (code)
        _throwErrno(code, msg, file, line);
}

///
struct DerelictJwtSigner {
    import std.array: Appender;
    import derelict.jwt.jwtfuncs;
    import derelict.jwt.jwttypes: jwt_t;
    import google_api.auth.service_account: Credentials, JwtClaims;

    private {
        Appender!(char[ ]) _payload;
        jwt_t* _jwt;
    }

    @disable this();
    @disable this(this);

    ///
    this(scope ref const Credentials credentials, int algo = JWT_ALG_RS256) scope @trusted {
        import std.array: appender;
        import std.conv: to;

        _payload = appender!(char[ ]);
        jwt_new(&_jwt)._enforce0("`jwt_new` failed");
        jwt_set_alg(_jwt, algo, credentials.privateKey.ptr, credentials.privateKey.length.to!int)
            ._enforce0("`jwt_set_alg` failed");
    }

    ~this() scope nothrow @trusted @nogc {
        jwt_free(_jwt);
    }

    ///
    void sign(
        scope ref const JwtClaims claims,
        scope void delegate(scope const(char)[ ]) @safe onSuccess,
    ) scope @trusted
    in(_jwt !is null)
    do {
        import core.stdc.stdlib: free;
        import std.exception: errnoEnforce;
        import std.string: fromStringz;
        import vibe.data.json: serializeToJson;

        // We have to communicate with `libjwt` via JSON because `jwt_add_grant_int` (which we would
        // need for `iat` and `exp`) takes a C `long`, which is only 32-bit-wide on some systems.
        // Also, while we could invoke `jwt_add_grant` for string fields, we would have to
        // zero-terminate their values. So it's simpler to just go JSON for everything.
        _payload.clear();
        _payload.serializeToJson(claims);
        _payload ~= '\0';
        jwt_add_grants_json(_jwt, _payload[ ].ptr)._enforce0("`jwt_add_grants_json` failed");

        char* signed = jwt_encode_str(_jwt).errnoEnforce("`jwt_encode_str` failed");
        // We should be freeing the string via `jwt_free_str`, but `derelict.jwt` does not bind it.
        // Therefore, we'll misbehave if the allocator has been changed via `jwt_set_alloc`
        // (somehow; that function isn't bound either).
        scope(exit) free(signed);

        onSuccess(signed.fromStringz());
    }
}
