# Overview

This is a LUA module written in C++ to read game info, which is not exposed by the given LUA API, directly from memory.

This lib uses the "external" approach to reading memory. This makes it easier to test and is (pretty much) exactly as fast as using the "internal" way.

## Features

### CCountry
- **getFlags**: Get a list of all current countryflags
- **getVariables**: Get a map onf all current countryVariables