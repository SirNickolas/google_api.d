module google_api.extras.fastjwt;

///
public import fastjwt.jwt: JWTAlgorithm;

@safe:

///
nothrow pure @nogc unittest {
    import google_api.auth.service_account: TokenManagerConfig;

    FastJwtSigner signer;
    TokenManagerConfig cfg = {
        signer: &signer.sign,
    };
}

///
struct FastJwtSigner {
    import stringbuffer: StringBuffer;
    import google_api.auth.service_account: Credentials, JwtClaims;

    private JWTAlgorithm _algo = JWTAlgorithm.HS256;
    private StringBuffer _buffer;

    ///
    this(JWTAlgorithm algo) scope inout nothrow pure @nogc { _algo = algo; }

    ///
    void sign(
        scope ref const Credentials credentials,
        scope ref const JwtClaims c,
        scope void delegate(scope const(char)[ ]) @safe onSuccess,
    ) scope @trusted {
        import fastjwt.jwt: encodeJWTToken;

        _buffer.removeAll();
        _buffer.encodeJWTToken(_algo, credentials.privateKey,
            "iss", c.iss, "scope", c.scope_, "aud", c.aud, "iat", c.iat, "exp", c.exp,
        );
        onSuccess(_buffer.getData!(const(char)[ ]));
    }
}
