module Lib where

import Prelude

import Data.Maybe (maybe)
import Effect (Effect)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Halogen.Aff as HA
import Halogen.VDom.Driver (runUI)
import Web.DOM.ParentNode (QuerySelector(..))
import Animator (component)

main :: Effect Unit
main = HA.runHalogenAff do
  HA.awaitLoad
  mel <- HA.selectElement (QuerySelector "#animator")
  el <- liftEffect $ maybe (throw "No #animator element found") pure mel
  void $ runUI component unit el
