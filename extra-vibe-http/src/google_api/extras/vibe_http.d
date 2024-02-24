module google_api.extras.vibe_http;

///
public import google_api.http;

///
nothrow pure @safe @nogc unittest {
    import google_api.auth.service_account: TokenManager, TokenManagerConfig;

    scope client = new VibeHttpClient;
    TokenManagerConfig cfg = {
        client: client,
    };
    scope auth = vibeAuthenticator(TokenManager(cfg));
}

///
@safe class VibeHttpClient: IHttpClient {
    import vibe.http.client: HTTPClientRequest, HTTPMethod;

    ///
    static HTTPMethod translateMethod(HttpMethod method) nothrow pure @nogc {
        final switch (method) with (HttpMethod) {
            case get:  return HTTPMethod.GET;
            case post: return HTTPMethod.POST;
        }
    }

    ///
    immutable(ubyte)[ ] request(
        scope ref const HttpRequestParams params,
        scope void delegate(scope HTTPClientRequest) @safe requester,
    ) scope @trusted {
        import vibe.http.client: requestHTTP;
        import vibe.stream.operations: readAll;

        immutable(ubyte)[ ] result;

        // We need `@trusted` all over the place because `vibe-http` disregards `scope`.
        requestHTTP(params.url, (scope req) @trusted {
            req.method = translateMethod(params.method);
            req.contentType = params.contentType;
            requester(req);
        }, (scope res) @trusted {
            res.readRawBody((scope InputStream stream) @trusted {
                result = cast(immutable)stream.readAll();
            });
        });

        return result;
    }

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
struct VibeAuthenticator(M) {
    import vibe.http.common: HTTPRequest;

    ///
    M mgr;

    ///
    void authenticate(scope HTTPRequest req) {
        req.headers.addField("Authorization", mgr.getHttpBearer());
    }
}

/// ditto
VibeAuthenticator!M vibeAuthenticator(M)(return scope M mgr) {
    import core.lifetime: move;

    return VibeAuthenticator!M(move(mgr));
}
