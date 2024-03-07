module google_api.d_extras.vibe_http;

///
public import google_api.d.http;

import vibe.http.client: HTTPClientRequest, HTTPClientResponse;

@safe:

///
nothrow pure @nogc unittest {
    import google_api.d.auth.service_account: TokenManager, TokenManagerConfig;

    scope authClient = new VibeHookingHttpClient(vibeNopMiddleware, vibeResponseReader);
    TokenManagerConfig cfg = {
        // ...
        client: authClient,
    };
    auto tokenMgr = TokenManager(cfg);
    VibeAuthenticator auth = {
        (() @trusted => &tokenMgr.getHttpBearer)(),
        vibeNopMiddleware,
    };
    scope client = new VibeHookingHttpClient((() @trusted => &auth.handle)(), vibeResponseReader);
}

///
abstract class VibeHttpClient: IHttpClient {
    import vibe.http.client: HTTPMethod;

    ///
    static HTTPMethod translateMethod(HttpMethod method) nothrow pure @nogc {
        final switch (method) with (HttpMethod) {
            case get:     return HTTPMethod.GET;
            case put:     return HTTPMethod.PUT;
            case post:    return HTTPMethod.POST;
            case patch:   return HTTPMethod.PATCH;
            case delete_: return HTTPMethod.DELETE;
        }
    }

    ///
    abstract ubyte[ ] request(
        scope ref const HttpRequestParams,
        scope void delegate(scope HTTPClientRequest) @safe,
    ) scope;

    final ubyte[ ] request(scope ref const HttpRequestParams params, scope InputStream data) scope {
        return request(params, (scope req) @trusted { req.writeBody(data); });
    }

    final ubyte[ ] request(
        scope ref const HttpRequestParams params, scope InputStream data, ulong length,
    ) scope {
        return request(params, (scope req) @trusted { req.writeBody(data, length); });
    }

    final ubyte[ ] request(scope ref const HttpRequestParams params, scope const(ubyte)[ ] data)
    scope {
        return request(params, (scope req) @trusted { req.writeBody(data); });
    }
}

///
alias VibeMiddleware = void delegate(
    scope HTTPClientRequest,
    scope void delegate(scope HTTPClientRequest) @safe,
) @safe;

///
class VibeHookingHttpClient: VibeHttpClient {
    private {
        VibeMiddleware _middleware;
        ubyte[ ] delegate(scope HTTPClientResponse) @safe _responseReader;
    }

    ///
    this(
        VibeMiddleware middleware,
        ubyte[ ] delegate(scope HTTPClientResponse) @safe responseReader,
    ) scope inout nothrow pure @nogc {
        _middleware = middleware;
        _responseReader = responseReader;
    }

    override ubyte[ ] request(
        scope ref const HttpRequestParams params,
        scope void delegate(scope HTTPClientRequest) @safe bodyWriter,
    ) scope @trusted {
        import vibe.http.client: requestHTTP;

        ubyte[ ] result;

        // We need `@trusted` all over the place because `vibe-http` disregards `scope`.
        requestHTTP(params.url, (scope req) @trusted {
            req.method = translateMethod(params.method);
            req.contentType = params.contentType;
            _middleware(req, bodyWriter);
        }, (scope res) @safe {
            result = _responseReader(res);
        });

        return result;
    }

    alias request = typeof(super).request;
}

///
immutable vibeNopMiddleware = delegate void(
    scope HTTPClientRequest req,
    scope void delegate(scope HTTPClientRequest) @safe bodyWriter,
) => bodyWriter(req);

///
struct VibeAuthenticator {
    private {
        string delegate() @safe _bearerFactory;
        VibeMiddleware _next;
    }

    ///
    void handle(
        scope HTTPClientRequest req,
        scope void delegate(scope HTTPClientRequest) @safe bodyWriter,
    ) scope {
        req.headers.addField("Authorization", _bearerFactory());
        _next(req, bodyWriter);
    }
}

///
immutable vibeResponseReader = delegate ubyte[ ](scope HTTPClientResponse res) @trusted {
    import vibe.stream.operations: readAll;

    auto result = res.bodyReader.readAll();
    enforceHttpStatus(res.statusCode, cast(string)result);
    return result;
};

///
class VibeAuthenticatingHttpClient: VibeHookingHttpClient {
    private VibeAuthenticator _auth;

    ///
    this(VibeAuthenticator auth, ubyte[ ] delegate(scope HTTPClientResponse) @safe responseReader)
    scope nothrow pure @trusted @nogc {
        _auth = auth;
        // `this._auth` will not outlive `this` so it is safe.
        super(&_auth.handle, responseReader);
    }
}
