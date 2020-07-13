# ios-wunderkammer

## Important

This is work in progress and documentation will follow. In the meantime you should start by reading the [bring your own pen device](https://www.aaronland.info/weblog/2020/06/16/revisiting/#pen) and [everyone gets a wunderkammer!](https://www.aaronland.info/weblog/2020/07/07/action/#wunderkammer) and [so that it may be remembered](https://www.aaronland.info/weblog/2020/07/13/experience/#remembered) blog posts.

## Config.xcconfig

For example:

```
SLASH = /

OAUTH2_CALLBACK_URL = wunderkammer:$(SLASH)/oauth2

ENABLE_SFOMUSEUM = YES

ENABLE_COOPERHEWITT = YES

ENABLE_SMITHSONIAN = YES

ENABLE_METMUSEUM = YES

COOPERHEWITT_AUTH_URL = https:$(SLASH)/collection.cooperhewitt.org/api/oauth2/authenticate/

COOPERHEWITT_TOKEN_URL = https:$(SLASH)/collection.cooperhewitt.org/api/oauth2/access_token/

COOPERHEWITT_CALLBACK_URL = $(OAUTH2_CALLBACK_URL)

COOPERHEWITT_CLIENT_ID = {YOUR COOPERHEWITT API KEY}

COOPERHEWITT_CLIENT_SECRET =

COOPERHEWITT_SCOPE = write

COOPERHEWITT_KEYCHAIN_LABEL = wunderkammer://collection.cooperhewitt.org/access_token
```

## Data sources

### Metropolitan Museum of Art

TBW.

In the meantime, there is an example for producing a `metmuseum.db` SQLite database in the [go-wunderkammer](https://github.com/aaronland/go-wunderkammer#wunderkammer-db) documentation.

### Smithsonian

Databases to enable support for the Smithsonian Institution need to be manually created using [Smithsonian Open Access](https://github.com/Smithsonian/OpenAccess) dataset as well as the the [go-smithsonian-openaccess](https://github.com/aaronland/go-smithsonian-openaccess) and [go-smithsonian-openaccess-database](https://github.com/aaronland/go-smithsonian-openaccess-database) packages. For example:
```
$> cd /usr/local/go-smithsonian-openaccess-database/

$> sqlite3 nmaahc.db < schema/sqlite/oembed.sqlite

$> /usr/local/go-smithsonian-openaccess/bin/emit -bucket-uri file:///usr/local/OpenAccess \
   -oembed metadata/objects/NMAAHC | \
   bin/oembed-populate -database-dsn sql://sqlite3/usr/local/go-smithsonian-openaccess-database/nmaahc.db
```

These databases will need to added to the `wunderkammer` application manually.

On iOS this involves copying them to the application's `Document` directory using the MacOS Finder (or iTunes application for pre-Catalina operating systems).

On MacOS these files will need to be copied in to `/Users/{USERNAME}/Library/Containers/info.aaronland.wunderkammer/Data/Documents/smithsonian`.

_Note: All of the above will be automated in future releases._

## See also

* https://developer.apple.com/documentation/corenfc
* https://github.com/aaronland/swift-oauth2-wrapper
* https://github.com/aaronland/swift-cooperhewitt-api
* https://github.com/ccgus/fmdb
* https://github.com/apple/swift-log