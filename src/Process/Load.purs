module Process.Load where

import Prelude

import Data.Maybe (Maybe(..))
import Effect.Aff (Aff, attempt)
import Effect.Class (liftEffect)
import Data.Either (Either(..))
import Process.Parse (parseTurtle)
import Process.Types (ProcessDef)

foreign import fetchText :: String -> Aff String

loadFromUrl :: String -> Aff (Maybe ProcessDef)
loadFromUrl url = do
  result <- attempt (fetchText url)
  case result of
    Left _ -> pure Nothing
    Right ttl -> liftEffect $ parseTurtle ttl
