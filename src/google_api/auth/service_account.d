module google_api.auth.service_account;

@safe:

///
struct Credentials {
    import vibe.data.json: name, optional;

    @name("client_email") string clientEmail; ///
    @name("private_key")  string privateKey; ///
    @name("token_uri") @optional string tokenUri = "https://www.googleapis.com/oauth2/v4/token"; ///
}

///
struct JwtClaims {
    string iss;    /// Issuer.
    string scope_; /// Scopes (space-separated).
    string aud;    /// Audience.
    long iat;      /// Issued at (Unix time).
    long exp;      /// Expires at (Unix time).
}

///
struct TokenManagerConfig {
    import core.time: Duration, hours, seconds;

    ///
    Credentials credentials;
    ///
    string scopes;
    ///
    void delegate(
        scope ref const Credentials,
        scope ref const JwtClaims,
        scope void delegate(scope const(char)[ ] base64) @safe,
    ) @safe signer;
    ///
    string delegate(scope string url, scope const(char)[ ] postData) @safe requester;
    /// How long the generated token will be valid.
    Duration duration = 1.hours; // Maximal allowed by Google.
    /// We consider the token expired before it actually does, to be safe against network delays and
    /// imprecise timing. Its effective life time is `duration - handicap`.
    Duration handicap = 30.seconds;
}

///
immutable defaultRequester = delegate(scope string url, scope const(char)[ ] data) @trusted {
    import vibe.http.client: HTTPMethod, requestHTTP;
    import vibe.stream.operations: readAllUTF8;

    string result;
    // We need `@trusted` here because `vibe-http` disregards `scope`.
    requestHTTP(url, (scope req) {
        req.method = HTTPMethod.POST;
        req.writeBody(cast(const(ubyte)[ ])data, "application/x-www-form-urlencoded");
    }, (scope res) {
        result = res.bodyReader.readAllUTF8();
    });
    return result;
};

///
nothrow pure @nogc unittest {
    TokenManagerConfig cfg = {
        requester: defaultRequester,
    };
}

///
JwtClaims createClaimsWithUnixTime(
    return scope ref const TokenManagerConfig cfg, long issueUnixTime,
) nothrow pure @nogc {
    JwtClaims result = {
        iss: cfg.credentials.clientEmail,
        scope_: cfg.scopes,
        aud: cfg.credentials.tokenUri,
        iat: issueUnixTime,
        exp: issueUnixTime + cfg.duration.total!`seconds`,
    };
    return result;
}

///
JwtClaims createClaims(return scope ref const TokenManagerConfig cfg, long issueStdTime)
nothrow pure @nogc {
    import std.datetime.systime: stdTimeToUnixTime;

    return cfg.createClaimsWithUnixTime(issueStdTime.stdTimeToUnixTime!long);
}

/// A tiny wrapper around `string` that only allows holding non-`scope` (i.e., heap-allocated) data.
private struct _GcString {
nothrow pure @nogc:
    private string _value;

    string toString() scope const @trusted {
        // The compiler doesn't let us return `_value` directly even in spite of `@trusted`.
        const result = _value;
        return result;
    }

    alias toString this;

    string opAssign(string s) scope {
        _value = s;
        return s;
    }
}

nothrow pure @nogc unittest {
    scope _GcString s = { "abc" };
    s = s;
    s = s.toString();
    s = "def";

    string* heap;
    scope string stack;
    static assert(is(typeof({ s = *heap; *heap = s; })));
    static assert(!__traits(compiles, s = stack));
}

private struct _Response {
    import vibe.data.json: name;

    @name("access_token") string accessToken;
}

///
struct TokenManager {
    import std.array: Appender;
    import std.typecons: Nullable;
    import vibe.http.common: HTTPRequest; // TODO: Move to a subpackage.

    private {
        TokenManagerConfig _cfg;
        Appender!(char[ ]) _postData;
        _GcString _bearer;
        long _expirationTime;
    }

    ///
    this(return scope TokenManagerConfig cfg) scope inout nothrow pure @nogc
    in(!cfg.handicap.isNegative)
    in(cfg.handicap < cfg.duration)
    do { _cfg = cfg; }

    @disable this(this);

    ///
    @property long expirationStdTime() scope const nothrow pure @nogc {
        return _expirationTime;
    }

    ///
    bool isExpiredAt(long stdTime) scope const nothrow pure @nogc {
        return stdTime >= _expirationTime;
    }

    ///
    @property bool expired() scope const {
        import std.datetime.systime: Clock;

        return isExpiredAt(Clock.currStdTime);
    }

    ///
    @property Nullable!(string, null) cachedHttpBearer() scope const {
        return expired ? typeof(return).init : typeof(return)(_bearer);
    }

    ///
    @property Nullable!(string, null) cachedToken() scope const {
        return expired ? typeof(return).init : typeof(return)(_bearer[7 .. $]);
    }

    private string _requestToken(scope const JwtClaims claims) scope {
        import vibe.data.json: deserializeJson;

        _postData.clear();
        _postData ~= "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=";
        _cfg.signer(_cfg.credentials, claims, (signed) { _postData ~= signed; });
        return _cfg
            .requester(_cfg.credentials.tokenUri, _postData[ ])
            .deserializeJson!_Response()
            .accessToken;
    }

    ///
    string getHttpBearer() scope {
        import std.datetime.systime: Clock;

        const now = Clock.currStdTime;
        if (!isExpiredAt(now))
            return _bearer;

        const result = _bearer = "Bearer " ~ _requestToken(_cfg.createClaims(now));
        _expirationTime = now + (_cfg.duration - _cfg.handicap).total!`hnsecs`;
        return result;
    }

    ///
    string getToken() scope { return getHttpBearer()[7 .. $]; }

    ///
    void authenticate(scope HTTPRequest req) scope {
        req.headers.addField("Authorization", getHttpBearer());
    }
}
