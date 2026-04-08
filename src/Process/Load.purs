module Process.Load where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (Aff, attempt)
import Effect.Class (liftEffect)
import Process.Parse (parseTurtle)
import Process.Types (ProcessDef)

foreign import fetchTextImpl :: String -> Effect (Promise String)

fetchText :: String -> Aff String
fetchText url = toAffE (fetchTextImpl url)

loadFromUrl :: String -> Aff (Maybe ProcessDef)
loadFromUrl url = do
  result <- attempt (fetchText url)
  case result of
    Left _ -> pure Nothing
    Right ttl -> liftEffect $ parseTurtle ttl
