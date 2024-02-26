module google_api.extras.vibe_http;

///
public import google_api.http;

import vibe.http.client: HTTPClientRequest, HTTPClientResponse;

@safe:

///
nothrow pure @nogc unittest {
    import google_api.auth.service_account: TokenManager, TokenManagerConfig;

    scope authClient = new VibeHookingHttpClient(vibeNopMiddleware, vibeResponseReader);
    TokenManagerConfig cfg = {
        client: authClient,
    };
    auto tokenMgr = TokenManager(cfg);
    VibeAuthenticator auth = {
        (() @trusted => &tokenMgr.getHttpBearer)(),
        vibeNopMiddleware,
    };
    scope client = new VibeHookingHttpClient((() @trusted => &auth.process)(), vibeResponseReader);
}

///
abstract class VibeHttpClient: IHttpClient {
    import vibe.http.client: HTTPMethod;

    ///
    static HTTPMethod translateMethod(HttpMethod method) nothrow pure @nogc {
        final switch (method) with (HttpMethod) {
            case get:  return HTTPMethod.GET;
            case post: return HTTPMethod.POST;
        }
    }

    ///
    abstract immutable(ubyte)[ ] request(
        scope ref const HttpRequestParams,
        scope void delegate(scope HTTPClientRequest) @safe,
    ) scope;

    final immutable(ubyte)[ ] request(
        scope ref const HttpRequestParams params, scope InputStream data,
    ) scope {
        return request(params, (scope req) @trusted { req.writeBody(data); });
    }

    final immutable(ubyte)[ ] request(
        scope ref const HttpRequestParams params, scope InputStream data, ulong length,
    ) scope {
        return request(params, (scope req) @trusted { req.writeBody(data, length); });
    }

    final immutable(ubyte)[ ] request(
        scope ref const HttpRequestParams params, scope const(ubyte)[ ] data,
    ) scope {
        return request(params, (scope req) @trusted { req.writeBody(data); });
    }
}

///
alias VibeMiddleware = void delegate(scope HTTPClientRequest, scope void delegate() @safe) @safe;

///
class VibeHookingHttpClient: VibeHttpClient {
    private {
        VibeMiddleware _middleware;
        immutable(ubyte)[ ] delegate(scope HTTPClientResponse) @safe _responseReader;
    }

    ///
    this(
        VibeMiddleware middleware,
        immutable(ubyte)[ ] delegate(scope HTTPClientResponse) @safe responseReader,
    ) scope inout nothrow pure @nogc {
        _middleware = middleware;
        _responseReader = responseReader;
    }

    ///
    override immutable(ubyte)[ ] request(
        scope ref const HttpRequestParams params,
        scope void delegate(scope HTTPClientRequest) @safe bodyWriter,
    ) scope @trusted {
        import vibe.http.client: requestHTTP;

        immutable(ubyte)[ ] result;

        // We need `@trusted` all over the place because `vibe-http` disregards `scope`.
        requestHTTP(params.url, (scope req) @trusted {
            req.method = translateMethod(params.method);
            req.contentType = params.contentType;
            _middleware(req, { bodyWriter(req); });
        }, (scope res) @safe {
            result = _responseReader(res);
        });

        return result;
    }

    alias request = typeof(super).request;
}

///
immutable vibeNopMiddleware =
delegate(scope .HTTPClientRequest, scope void delegate() @safe bodyWriter) {
    bodyWriter();
};

///
struct VibeAuthenticator {
    private {
        string delegate() @safe _bearerFactory;
        VibeMiddleware _next;
    }

    ///
    void process(
        scope HTTPClientRequest req,
        scope void delegate() @safe bodyWriter,
    ) scope {
        req.headers.addField("Authorization", _bearerFactory());
        _next(req, bodyWriter);
    }
}

///
immutable vibeResponseReader = delegate immutable(ubyte)[ ](scope HTTPClientResponse res) {
    import vibe.stream.operations: readAll;

    const result = (() @trusted => cast(immutable)res.bodyReader.readAll())();
    enforceHttpStatus(res.statusCode, cast(string)result);
    return result;
};
