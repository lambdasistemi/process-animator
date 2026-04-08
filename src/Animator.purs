module Animator where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe, isJust)
import Data.String (null) as Str
import Data.String.Common (split) as Str
import Data.String.Pattern (Pattern(..))
import Effect.Aff (Milliseconds(..), delay)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (liftEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Process.Load (loadFromUrl)
import Process.Types (AnimatorState, DatumChange, PlaybackState(..), ProcessDef, SignatureReq, Step, StepType(..), initialState)
import Web.HTML (window)
import Web.HTML.Location (search)
import Web.HTML.Window (location)

data Action
  = Initialize
  | StepForward
  | StepBackward
  | TogglePlay
  | Reset
  | LoadResult (Maybe ProcessDef)
  | LoadError String
  | Tick

component :: forall q i o m. MonadAff m => H.Component q i o m
component =
  H.mkComponent
    { initialState: const initialState
    , render
    , eval: H.mkEval H.defaultEval
        { handleAction = handleAction
        , initialize = Just Initialize
        }
    }

render :: forall cs m. AnimatorState -> H.ComponentHTML Action cs m
render state =
  HH.div
    [ HP.class_ (H.ClassName "animator") ]
    [ renderControls state
    , case state.error of
        Just err -> renderError err
        Nothing -> case state.process of
          Nothing -> renderEmpty
          Just p -> renderProcess state p
    ]

renderError :: forall cs m. String -> H.ComponentHTML Action cs m
renderError err =
  HH.div
    [ HP.class_ (H.ClassName "error-state") ]
    [ HH.h2_ [ HH.text "Error" ]
    , HH.p_ [ HH.text err ]
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
        , HP.disabled (not (isJust state.process))
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
    , HH.p_ [ HH.text "Add ?ttl=<url> to load a process." ]
    ]

renderProcess :: forall cs m. AnimatorState -> ProcessDef -> H.ComponentHTML Action cs m
renderProcess state p =
  let
    currentStepDef = Array.index p.steps state.currentStep
    activeDeadline = Array.find
      ( \dl ->
          Array.any
            ( \step ->
                step.fromState == Just dl.fromState || step.toState == Just dl.toState
            )
            p.steps
      )
      p.deadlines
  in
    HH.div
      [ HP.class_ (H.ClassName "process-view") ]
      [ HH.h2
          [ HP.class_ (H.ClassName "process-title") ]
          [ HH.text p.label ]
      , case activeDeadline of
          Nothing -> HH.text ""
          Just dl -> renderDeadline state p dl
      , HH.div
          [ HP.class_ (H.ClassName "lanes-container") ]
          [ HH.div
              [ HP.class_ (H.ClassName "lanes") ]
              (map (renderLane state p) p.actors)
          , case currentStepDef of
              Nothing -> HH.text ""
              Just step ->
                if step.stepType == OnChain then renderArrow p step
                else HH.text ""
          ]
      , HH.div
          [ HP.class_ (H.ClassName "step-info") ]
          [ case currentStepDef of
              Nothing -> HH.text ""
              Just step -> renderStepInfo p step
          ]
      ]

renderDeadline :: forall cs m. AnimatorState -> ProcessDef -> { label :: String, duration :: String, fromState :: String, toState :: String } -> H.ComponentHTML Action cs m
renderDeadline state p dl =
  let
    totalSteps = Array.length p.steps
    progress = if totalSteps > 1 then (state.currentStep * 100) / (totalSteps - 1) else 0
  in
    HH.div
      [ HP.class_ (H.ClassName "deadline-bar") ]
      [ HH.div
          [ HP.class_ (H.ClassName "deadline-label") ]
          [ HH.text (dl.label <> " (" <> dl.duration <> ")") ]
      , HH.div
          [ HP.class_ (H.ClassName "deadline-track") ]
          [ HH.div
              [ HP.class_ (H.ClassName "deadline-fill")
              , HP.attr (HH.AttrName "style") ("width: " <> show progress <> "%")
              ]
              []
          ]
      ]

renderArrow :: forall cs m. ProcessDef -> Step -> H.ComponentHTML Action cs m
renderArrow p step =
  let
    sourceLane = fromMaybe 0 $ Array.findIndex (\a -> a.id == step.actor) p.actors
    laneCount = Array.length p.actors
    direction = if sourceLane == 0 then "right" else "left"
    leftPct = (min sourceLane 1 * 100) / laneCount
    widthPct = (max 1 (abs (sourceLane - 1)) * 100) / laneCount
  in
    HH.div
      [ HP.class_ (H.ClassName ("tx-arrow tx-arrow-" <> direction))
      , HP.attr (HH.AttrName "style")
          ("left: " <> show leftPct <> "%; width: " <> show widthPct <> "%")
      ]
      [ HH.div [ HP.class_ (H.ClassName "arrow-line") ] []
      , HH.div [ HP.class_ (H.ClassName "arrow-head") ] []
      ]
  where
  abs n = if n < 0 then -n else n

renderLane :: forall cs m. AnimatorState -> ProcessDef -> { id :: String, label :: String, lane :: Int } -> H.ComponentHTML Action cs m
renderLane state p actor =
  let
    currentStepDef = Array.index p.steps state.currentStep
    chainState = do
      step <- currentStepDef
      toSt <- step.toState
      Array.find (\ls -> ls.id == toSt) p.lifecycleStates
    prevState = do
      step <- currentStepDef
      fromSt <- step.fromState
      Array.find (\ls -> ls.id == fromSt) p.lifecycleStates
    hasStateInfo = isJust chainState || isJust prevState
  in
    HH.div
      [ HP.class_ (H.ClassName "lane")
      , HP.attr (HH.AttrName "data-lane") (show actor.lane)
      ]
      [ HH.div
          [ HP.class_ (H.ClassName "lane-header") ]
          [ HH.text actor.label ]
      , if hasStateInfo then
          HH.div
            [ HP.class_ (H.ClassName "chain-state-box") ]
            [ case chainState of
                Just cs -> HH.div [ HP.class_ (H.ClassName "chain-state-label chain-state-active") ] [ HH.text cs.label ]
                Nothing -> case prevState of
                  Just ps -> HH.div [ HP.class_ (H.ClassName "chain-state-label") ] [ HH.text ps.label ]
                  Nothing -> HH.text ""
            , case currentStepDef of
                Just step | step.stepType == OnChain && Array.length step.datumChanges > 0 ->
                  HH.div
                    [ HP.class_ (H.ClassName "datum-changes") ]
                    (map renderDatumChange step.datumChanges)
                _ -> HH.text ""
            ]
        else HH.text ""
      , HH.div
          [ HP.class_ (H.ClassName "lane-body") ]
          (map (renderStepInLane state actor.id) p.steps)
      ]

renderDatumChange :: forall cs m. DatumChange -> H.ComponentHTML Action cs m
renderDatumChange dc =
  HH.div
    [ HP.class_ (H.ClassName "datum-change") ]
    [ HH.span [ HP.class_ (H.ClassName "datum-field") ] [ HH.text dc.field ]
    , HH.div [ HP.class_ (H.ClassName "datum-before") ] [ HH.text dc.beforeValue ]
    , HH.div [ HP.class_ (H.ClassName "datum-arrow") ] [ HH.text "\x2192" ]
    , HH.div [ HP.class_ (H.ClassName "datum-after") ] [ HH.text dc.afterValue ]
    ]

renderStepInLane :: forall cs m. AnimatorState -> String -> Step -> H.ComponentHTML Action cs m
renderStepInLane state actorId step =
  let
    stepIdx = step.order - 1
    isActive = state.currentStep == stepIdx
    isCompleted = state.currentStep > stepIdx
    belongsToLane = step.actor == actorId
    isOffChainActive = isActive && step.stepType == OffChain && belongsToLane
    className = "step-marker"
      <> (if isActive then " active" else "")
      <> (if isCompleted then " completed" else "")
      <> (if belongsToLane then " owns" else "")
      <> (if isOffChainActive then " offchain-active" else "")
  in
    HH.div
      [ HP.class_ (H.ClassName className) ]
      [ if belongsToLane then HH.text step.label else HH.text "" ]

renderStepInfo :: forall cs m. ProcessDef -> Step -> H.ComponentHTML Action cs m
renderStepInfo _p step =
  HH.div
    [ HP.class_ (H.ClassName "step-detail") ]
    [ HH.div
        [ HP.class_ (H.ClassName "step-type-badge") ]
        [ HH.text case step.stepType of
            OnChain -> "On-chain"
            OffChain -> "Off-chain"
        ]
    , HH.h3_ [ HH.text step.label ]
    , case step.narrative of
        Nothing -> HH.text ""
        Just narr -> HH.p_ [ HH.text narr ]
    , if Array.length step.signatures > 0 then
        HH.div
          [ HP.class_ (H.ClassName "sig-badges") ]
          (map renderSigBadge step.signatures)
      else HH.text ""
    , if Array.length step.checks > 0 then
        HH.div
          [ HP.class_ (H.ClassName "check-ticks") ]
          ( Array.mapWithIndex
              ( \i checkUri ->
                  HH.span
                    [ HP.class_ (H.ClassName "check-tick")
                    , HP.attr (HH.AttrName "style") ("animation-delay: " <> show (i * 200) <> "ms")
                    ]
                    [ HH.text ("\x2713 " <> stripCheckName checkUri) ]
              )
              step.checks
          )
      else HH.text ""
    , if Array.length step.datumChanges > 0 then
        HH.div
          [ HP.class_ (H.ClassName "datum-changes-info") ]
          (map renderDatumChangeInfo step.datumChanges)
      else HH.text ""
    ]

renderSigBadge :: forall cs m. SignatureReq -> H.ComponentHTML Action cs m
renderSigBadge sig =
  HH.span
    [ HP.class_ (H.ClassName "sig-badge") ]
    [ HH.text sig.label ]

renderDatumChangeInfo :: forall cs m. DatumChange -> H.ComponentHTML Action cs m
renderDatumChangeInfo dc =
  HH.div
    [ HP.class_ (H.ClassName "datum-change-info") ]
    [ HH.strong_ [ HH.text dc.label ]
    , HH.span [ HP.class_ (H.ClassName "datum-field-name") ] [ HH.text dc.field ]
    , HH.div [ HP.class_ (H.ClassName "datum-transition") ]
        [ HH.span [ HP.class_ (H.ClassName "datum-val-before") ] [ HH.text dc.beforeValue ]
        , HH.span_ [ HH.text " \x2192 " ]
        , HH.span [ HP.class_ (H.ClassName "datum-val-after") ] [ HH.text dc.afterValue ]
        ]
    ]

stripCheckName :: String -> String
stripCheckName uri =
  let
    parts = Str.split (Pattern "#") uri
    after = fromMaybe uri (Array.last parts)
    segments = Str.split (Pattern "G_") after
  in
    if Array.length segments > 1 then fromMaybe after (Array.index segments 1)
    else after

canStepForward :: AnimatorState -> Boolean
canStepForward state = case state.process of
  Nothing -> false
  Just p -> state.currentStep < Array.length p.steps - 1

handleAction :: forall cs o m. MonadAff m => Action -> H.HalogenM AnimatorState Action cs o m Unit
handleAction = case _ of
  Initialize -> do
    loc <- liftEffect $ window >>= location
    qs <- liftEffect $ search loc
    let ttlUrl = extractParam "ttl" qs
    case ttlUrl of
      Nothing -> pure unit
      Just url -> do
        result <- liftAff $ loadFromUrl url
        case result of
          Nothing -> handleAction (LoadError ("Failed to load: " <> url))
          Just p -> handleAction (LoadResult (Just p))

  StepForward -> do
    state <- H.get
    when (canStepForward state) do
      H.modify_ \s -> s { currentStep = s.currentStep + 1 }

  StepBackward -> do
    H.modify_ \s -> s { currentStep = max 0 (s.currentStep - 1) }

  TogglePlay -> do
    state <- H.get
    case state.playback of
      Playing ->
        H.modify_ \s -> s { playback = Paused }
      _ -> do
        H.modify_ \s -> s { playback = Playing }
        startPlayback

  Reset ->
    H.modify_ \s -> s { currentStep = 0, playback = Stopped }

  LoadResult mp ->
    H.modify_ \s -> s { process = mp, currentStep = 0, playback = Stopped, error = Nothing }

  LoadError err ->
    H.modify_ \s -> s { error = Just err }

  Tick -> do
    state <- H.get
    case state.playback of
      Playing ->
        if canStepForward state then do
          H.modify_ \s -> s { currentStep = s.currentStep + 1 }
          liftAff $ delay (Milliseconds 2500.0)
          handleAction Tick
        else
          H.modify_ \s -> s { playback = Stopped }
      _ -> pure unit

startPlayback :: forall cs o m. MonadAff m => H.HalogenM AnimatorState Action cs o m Unit
startPlayback = do
  liftAff $ delay (Milliseconds 2500.0)
  handleAction Tick

extractParam :: String -> String -> Maybe String
extractParam key qs =
  let
    q = if Str.null qs then ""
        else fromMaybe qs (Array.last (Str.split (Pattern "?") qs))
    pairs = Str.split (Pattern "&") q
    findPair = Array.find
      ( \pair ->
          let kv = Str.split (Pattern "=") pair
          in Array.index kv 0 == Just key
      )
      pairs
  in
    case findPair of
      Nothing -> Nothing
      Just pair ->
        let kv = Str.split (Pattern "=") pair
        in Array.index kv 1
