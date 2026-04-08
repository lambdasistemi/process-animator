module Animator where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Process.Types (AnimatorState, PlaybackState(..), ProcessDef, Step, StepType(..), initialState)

data Action
  = StepForward
  | StepBackward
  | TogglePlay
  | Reset

component :: forall q i o m. MonadAff m => H.Component q i o m
component =
  H.mkComponent
    { initialState: const initialState
    , render
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }

render :: forall cs m. AnimatorState -> H.ComponentHTML Action cs m
render state =
  HH.div
    [ HP.class_ (H.ClassName "animator") ]
    [ renderControls state
    , case state.process of
        Nothing -> renderEmpty
        Just proc -> renderProcess state proc
    ]

renderControls :: forall cs m. AnimatorState -> H.ComponentHTML Action cs m
renderControls state =
  HH.div
    [ HP.class_ (H.ClassName "controls") ]
    [ HH.button
        [ HP.class_ (H.ClassName "control-btn")
        , HE.onClick \_ -> StepBackward
        , HP.disabled (state.currentStep <= 0)
        ]
        [ HH.text "\x25C0 Back" ]
    , HH.button
        [ HP.class_ (H.ClassName "control-btn")
        , HE.onClick \_ -> TogglePlay
        ]
        [ HH.text case state.playback of
            Playing -> "\x23F8 Pause"
            _ -> "\x25B6 Play"
        ]
    , HH.button
        [ HP.class_ (H.ClassName "control-btn")
        , HE.onClick \_ -> StepForward
        , HP.disabled (not (canStepForward state))
        ]
        [ HH.text "Next \x25B6" ]
    , HH.button
        [ HP.class_ (H.ClassName "control-btn")
        , HE.onClick \_ -> Reset
        ]
        [ HH.text "\x23EE Reset" ]
    ]

renderEmpty :: forall cs m. H.ComponentHTML Action cs m
renderEmpty =
  HH.div
    [ HP.class_ (H.ClassName "empty-state") ]
    [ HH.h2_ [ HH.text "Process Animator" ]
    , HH.p_ [ HH.text "Load a process ontology (TTL) to begin." ]
    ]

renderProcess :: forall cs m. AnimatorState -> ProcessDef -> H.ComponentHTML Action cs m
renderProcess state proc =
  HH.div
    [ HP.class_ (H.ClassName "process-view") ]
    [ HH.h2
        [ HP.class_ (H.ClassName "process-title") ]
        [ HH.text proc.label ]
    , HH.div
        [ HP.class_ (H.ClassName "lanes") ]
        (map (renderLane state proc) proc.actors)
    , HH.div
        [ HP.class_ (H.ClassName "step-info") ]
        [ case Array.index proc.steps state.currentStep of
            Nothing -> HH.text ""
            Just step -> renderStepInfo step
        ]
    ]

renderLane :: forall cs m. AnimatorState -> ProcessDef -> { id :: String, label :: String, lane :: Int } -> H.ComponentHTML Action cs m
renderLane state proc actor =
  HH.div
    [ HP.class_ (H.ClassName "lane")
    , HP.attr (HH.AttrName "data-lane") (show actor.lane)
    ]
    [ HH.div
        [ HP.class_ (H.ClassName "lane-header") ]
        [ HH.text actor.label ]
    , HH.div
        [ HP.class_ (H.ClassName "lane-body") ]
        (map (renderStepInLane state actor.id) proc.steps)
    ]

renderStepInLane :: forall cs m. AnimatorState -> String -> Step -> H.ComponentHTML Action cs m
renderStepInLane state actorId step =
  let
    isActive = state.currentStep == step.order
    isCompleted = state.currentStep > step.order
    belongsToLane = step.actor == actorId
    className = "step-marker"
      <> (if isActive then " active" else "")
      <> (if isCompleted then " completed" else "")
      <> (if belongsToLane then " owns" else "")
  in
    HH.div
      [ HP.class_ (H.ClassName className) ]
      [ if belongsToLane then HH.text step.label else HH.text "" ]

renderStepInfo :: forall cs m. Step -> H.ComponentHTML Action cs m
renderStepInfo step =
  HH.div
    [ HP.class_ (H.ClassName "step-detail") ]
    [ HH.div
        [ HP.class_ (H.ClassName "step-type-badge") ]
        [ HH.text case step.stepType of
            Transaction -> "Transaction"
            OffChain -> "Off-chain"
            Query -> "Query"
        ]
    , HH.h3_ [ HH.text step.label ]
    , case step.description of
        Nothing -> HH.text ""
        Just desc -> HH.p_ [ HH.text desc ]
    ]

canStepForward :: AnimatorState -> Boolean
canStepForward state = case state.process of
  Nothing -> false
  Just proc -> state.currentStep < Array.length proc.steps - 1

handleAction :: forall cs o m. MonadAff m => Action -> H.HalogenM AnimatorState Action cs o m Unit
handleAction = case _ of
  StepForward -> do
    state <- H.get
    when (canStepForward state) do
      H.modify_ \s -> s { currentStep = s.currentStep + 1 }
  StepBackward -> do
    H.modify_ \s -> s { currentStep = max 0 (s.currentStep - 1) }
  TogglePlay -> do
    H.modify_ \s -> s
      { playback = case s.playback of
          Playing -> Paused
          _ -> Playing
      }
  Reset -> do
    H.modify_ \s -> s { currentStep = 0, playback = Stopped }
