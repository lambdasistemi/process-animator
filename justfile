build:
    spago build

bundle:
    # 1. Bundle npm deps into a single file
    esbuild src/bootstrap.js --bundle --outfile=dist/deps.js --format=iife --platform=browser --loader:.wasm=binary --minify
    # 2. Bundle PureScript app (Main module)
    spago bundle --module Main --outfile dist/index.js
    # 3. Concatenate: deps first, then app
    cat dist/deps.js dist/index.js > dist/bundle.js
    mv dist/bundle.js dist/index.js
    rm dist/deps.js

bundle-lib:
    # 1. Bundle npm deps into a single file
    esbuild src/bootstrap.js --bundle --outfile=dist/deps.js --format=iife --platform=browser --loader:.wasm=binary --minify
    # 2. Bundle PureScript lib (Lib module)
    spago bundle --module Lib --outfile dist/index.js
    # 3. Concatenate: deps first, then app
    cat dist/deps.js dist/index.js > dist/bundle.js
    mv dist/bundle.js dist/index.js
    rm dist/deps.js

dev:
    spago build --watch

format:
    purs-tidy format-in-place src/**/*.purs

format-check:
    purs-tidy check src/**/*.purs

install:
    npm ci

ci: install format-check build bundle

serve: bundle
    npx serve dist -p 10003

clean:
    rm -rf output/ dist/index.js dist/deps.js dist/bundle.js
