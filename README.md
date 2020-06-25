# ios-wunderkammer

## Important

This is work in progress and documentation will follow. In the meantime you should start by reading the [bring your own pen device](https://www.aaronland.info/weblog/2020/06/16/revisiting/#pen) blog post.

## Config.xcconfig

For example:

```
SLASH = /

OAUTH2_CALLBACK_URL = wunderkammer:$(SLASH)/oauth2

ENABLE_SFOMUSEUM = YES

ENABLE_COOPERHEWITT = YES

COOPERHEWITT_AUTH_URL = https:$(SLASH)/collection.cooperhewitt.org/api/oauth2/authenticate/

COOPERHEWITT_TOKEN_URL = https:$(SLASH)/collection.cooperhewitt.org/api/oauth2/access_token/

COOPERHEWITT_CALLBACK_URL = $(OAUTH2_CALLBACK_URL)

COOPERHEWITT_CLIENT_ID = {YOUR COOPERHEWITT API KEY}

COOPERHEWITT_CLIENT_SECRET =

COOPERHEWITT_SCOPE = write

COOPERHEWITT_KEYCHAIN_LABEL = wunderkammer://collection.cooperhewitt.org/access_token
```

## See also

* https://developer.apple.com/documentation/corenfc
* https://github.com/aaronland/swift-oauth2-wrapper
* https://github.com/aaronland/swift-cooperhewitt-api
* https://github.com/ccgus/fmdb
* https://github.com/apple/swift-log