module FFI.Oxigraph where

import Effect (Effect)

type RdfObject =
  { value :: String
  , type :: String
  , datatype :: String
  , language :: String
  }

type RdfQuad =
  { subject :: String
  , predicate :: String
  , object :: RdfObject
  }

foreign import parseQuadsImpl :: String -> String -> String -> Effect (Array RdfQuad)

-- | Parse RDF quads from a string.
-- | format: "text/turtle", "application/n-triples", etc.
parseQuads :: String -> String -> String -> Effect (Array RdfQuad)
parseQuads = parseQuadsImpl
