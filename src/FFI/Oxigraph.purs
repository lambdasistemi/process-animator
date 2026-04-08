module FFI.Oxigraph where

import Effect (Effect)

type RdfObject =
  { termType :: String
  , value :: String
  , datatype :: String
  , language :: String
  }

type RdfQuad =
  { subject :: String
  , predicate :: String
  , object :: RdfObject
  }

foreign import parseQuadsImpl :: String -> String -> String -> Effect (Array RdfQuad)

parseQuads :: String -> String -> String -> Effect (Array RdfQuad)
parseQuads = parseQuadsImpl
