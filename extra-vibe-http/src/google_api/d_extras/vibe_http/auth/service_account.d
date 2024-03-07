module google_api.d_extras.vibe_http.auth.service_account;

///
public {
    import google_api.d.auth.service_account: TokenManagerConfig;
    import google_api.d_extras.vibe_http;
}

@safe:

///
class VibeTokenRequestingHttpClient: VibeAuthenticatingHttpClient {
    import vibe.http.client: HTTPClientResponse;
    import google_api.d.auth.service_account: TokenManager;

    private TokenManager _mgr;

    ///
    this(
        TokenManagerConfig cfg,
        VibeMiddleware middleware,
        ubyte[ ] delegate(scope HTTPClientResponse) @safe responseReader,
    ) scope nothrow pure @trusted @nogc {
        _mgr = TokenManager(cfg);
        // `this._mgr` will not outlive `this` so it is safe.
        super(VibeAuthenticator(&_mgr.getHttpBearer, middleware), responseReader);
    }
}
