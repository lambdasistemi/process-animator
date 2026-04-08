module Animator where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe, isJust)
import Data.String (null) as Str
import Data.String.Common (split) as Str
import Data.String.Pattern (Pattern(..))
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (liftEffect)
import Effect.Timer (clearInterval, setInterval)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS
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
    [ case state.error of
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
    activeDeadline = Array.head p.deadlines
    totalSteps = Array.length p.steps
    -- Find current lifecycle state
    currentLifecycleLabel = do
      step <- currentStepDef
      toSt <- step.toState
      ls <- Array.find (\l -> l.id == toSt) p.lifecycleStates
      pure ls.label
    prevLifecycleLabel = do
      step <- currentStepDef
      fromSt <- step.fromState
      ls <- Array.find (\l -> l.id == fromSt) p.lifecycleStates
      pure ls.label
  in
    HH.div
      [ HP.class_ (H.ClassName "process-view") ]
      [ -- Header
        HH.div
          [ HP.class_ (H.ClassName "process-header") ]
          [ HH.div
              [ HP.class_ (H.ClassName "process-header-left") ]
              [ HH.h1_ [ HH.text p.label ]
              , case p.description of
                  Nothing -> HH.text ""
                  Just desc -> HH.p [ HP.class_ (H.ClassName "process-desc") ] [ HH.text desc ]
              ]
          , HH.div
              [ HP.class_ (H.ClassName "process-header-right") ]
              [ HH.div
                  [ HP.class_ (H.ClassName "step-counter") ]
                  [ HH.text ("Step " <> show (state.currentStep + 1) <> " of " <> show totalSteps) ]
              , case activeDeadline of
                  Nothing -> HH.text ""
                  Just dl -> renderDeadline state totalSteps dl
              ]
          ]
        -- Chain state banner
      , HH.div
          [ HP.class_ (H.ClassName "chain-state-banner") ]
          [ HH.span [ HP.class_ (H.ClassName "chain-label") ] [ HH.text "Chain state:" ]
          , case currentLifecycleLabel of
              Just lbl -> HH.span [ HP.class_ (H.ClassName "chain-value chain-value-active") ] [ HH.text lbl ]
              Nothing -> case prevLifecycleLabel of
                Just lbl -> HH.span [ HP.class_ (H.ClassName "chain-value") ] [ HH.text lbl ]
                Nothing -> HH.span [ HP.class_ (H.ClassName "chain-value") ] [ HH.text "—" ]
          ]
        -- Controls
      , renderControls state
        -- Timeline
      , HH.div
          [ HP.class_ (H.ClassName "timeline") ]
          (Array.mapWithIndex (renderStep state p) p.steps)
      ]

renderDeadline :: forall cs m. AnimatorState -> Int -> { label :: String, duration :: String, fromState :: String, toState :: String } -> H.ComponentHTML Action cs m
renderDeadline state totalSteps dl =
  let
    progress = if totalSteps > 1 then (state.currentStep * 100) / (totalSteps - 1) else 0
  in
    HH.div
      [ HP.class_ (H.ClassName "deadline") ]
      [ HH.div [ HP.class_ (H.ClassName "deadline-text") ]
          [ HH.text (dl.label <> " (" <> dl.duration <> ")") ]
      , HH.div [ HP.class_ (H.ClassName "deadline-track") ]
          [ HH.div
              [ HP.class_ (H.ClassName "deadline-fill")
              , HP.attr (HH.AttrName "style") ("width: " <> show progress <> "%")
              ]
              []
          ]
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
        [ HP.class_ (H.ClassName "control-btn control-btn-play")
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

renderStep :: forall cs m. AnimatorState -> ProcessDef -> Int -> Step -> H.ComponentHTML Action cs m
renderStep state p idx step =
  let
    stepIdx = step.order - 1
    isActive = state.currentStep == stepIdx
    isCompleted = state.currentStep > stepIdx
    isFuture = state.currentStep < stepIdx
    actorLabel = fromMaybe "Unknown" $ do
      actor <- Array.find (\a -> a.id == step.actor) p.actors
      pure actor.label
    cardClass = "step-card"
      <> (if isActive then " step-active" else "")
      <> (if isCompleted then " step-completed" else "")
      <> (if isFuture then " step-future" else "")
  in
    HH.div
      [ HP.class_ (H.ClassName cardClass) ]
      [ -- Step number + connector line
        HH.div
          [ HP.class_ (H.ClassName "step-connector") ]
          [ HH.div [ HP.class_ (H.ClassName "step-number") ]
              [ HH.text (show step.order) ]
          , if idx < Array.length p.steps - 1 then
              HH.div [ HP.class_ (H.ClassName "step-line") ] []
            else HH.text ""
          ]
        -- Step content
      , HH.div
          [ HP.class_ (H.ClassName "step-content") ]
          [ -- Badges row
            HH.div
              [ HP.class_ (H.ClassName "step-badges") ]
              [ HH.span
                  [ HP.class_ (H.ClassName ("step-type-badge step-type-" <> stepTypeClass step.stepType)) ]
                  [ HH.text (stepTypeLabel step.stepType) ]
              , HH.span
                  [ HP.class_ (H.ClassName "step-actor-badge") ]
                  [ HH.text actorLabel ]
              ]
            -- Title
          , HH.h3 [ HP.class_ (H.ClassName "step-title") ] [ HH.text step.label ]
            -- Narrative (only when active or completed)
          , if isActive || isCompleted then
              case step.narrative of
                Nothing -> HH.text ""
                Just narr -> HH.p [ HP.class_ (H.ClassName "step-narrative") ] [ HH.text narr ]
            else HH.text ""
            -- On-chain details (only when active)
          , if isActive && step.stepType == OnChain then
              renderOnChainDetails p step
            else HH.text ""
          ]
      ]

renderOnChainDetails :: forall cs m. ProcessDef -> Step -> H.ComponentHTML Action cs m
renderOnChainDetails p step =
  HH.div
    [ HP.class_ (H.ClassName "onchain-details") ]
    [ -- State transition
      case step.fromState, step.toState of
        Just fromSt, Just toSt ->
          let
            fromLabel = fromMaybe (stripUri fromSt) $ do
              ls <- Array.find (\l -> l.id == fromSt) p.lifecycleStates
              pure ls.label
            toLabel = fromMaybe (stripUri toSt) $ do
              ls <- Array.find (\l -> l.id == toSt) p.lifecycleStates
              pure ls.label
          in
            HH.div [ HP.class_ (H.ClassName "state-transition") ]
              [ HH.span [ HP.class_ (H.ClassName "state-from") ] [ HH.text fromLabel ]
              , HH.span [ HP.class_ (H.ClassName "state-arrow") ] [ HH.text "\x2192" ]
              , HH.span [ HP.class_ (H.ClassName "state-to") ] [ HH.text toLabel ]
              ]
        _, _ -> HH.text ""
      -- Datum changes
    , if Array.length step.datumChanges > 0 then
        HH.div [ HP.class_ (H.ClassName "datum-changes") ]
          (map renderDatumChange step.datumChanges)
      else HH.text ""
      -- Signatures
    , if Array.length step.signatures > 0 then
        HH.div [ HP.class_ (H.ClassName "sig-section") ]
          [ HH.span [ HP.class_ (H.ClassName "section-label") ] [ HH.text "Signatures" ]
          , HH.div [ HP.class_ (H.ClassName "sig-badges") ]
              (map renderSigBadge step.signatures)
          ]
      else HH.text ""
      -- Validator checks
    , if Array.length step.checks > 0 then
        HH.div [ HP.class_ (H.ClassName "checks-section") ]
          [ HH.span [ HP.class_ (H.ClassName "section-label") ] [ HH.text "Validator checks" ]
          , HH.div [ HP.class_ (H.ClassName "check-ticks") ]
              ( Array.mapWithIndex
                  ( \i checkUri ->
                      HH.span
                        [ HP.class_ (H.ClassName "check-tick")
                        , HP.attr (HH.AttrName "style") ("animation-delay: " <> show (i * 150) <> "ms")
                        ]
                        [ HH.text ("\x2713 " <> stripCheckName checkUri) ]
                  )
                  step.checks
              )
          ]
      else HH.text ""
    ]

renderDatumChange :: forall cs m. DatumChange -> H.ComponentHTML Action cs m
renderDatumChange dc =
  HH.div
    [ HP.class_ (H.ClassName "datum-change") ]
    [ HH.div [ HP.class_ (H.ClassName "datum-header") ]
        [ HH.strong_ [ HH.text dc.label ]
        , HH.code_ [ HH.text dc.field ]
        ]
    , HH.div [ HP.class_ (H.ClassName "datum-values") ]
        [ HH.span [ HP.class_ (H.ClassName "datum-before") ] [ HH.text dc.beforeValue ]
        , HH.span [ HP.class_ (H.ClassName "datum-arrow") ] [ HH.text "\x2192" ]
        , HH.span [ HP.class_ (H.ClassName "datum-after") ] [ HH.text dc.afterValue ]
        ]
    ]

renderSigBadge :: forall cs m. SignatureReq -> H.ComponentHTML Action cs m
renderSigBadge sig =
  HH.span
    [ HP.class_ (H.ClassName "sig-badge") ]
    [ HH.text sig.label ]

stepTypeClass :: StepType -> String
stepTypeClass = case _ of
  OnChain -> "onchain"
  OffChain -> "offchain"

stepTypeLabel :: StepType -> String
stepTypeLabel = case _ of
  OnChain -> "On-chain"
  OffChain -> "Off-chain"

stripUri :: String -> String
stripUri uri =
  let
    parts = Str.split (Pattern "#") uri
    after = fromMaybe uri (Array.last parts)
  in
    fromMaybe after (Array.last (Str.split (Pattern "/") after))

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
      Playing -> stopPlayback
      _ -> startPlayback

  Reset -> do
    stopPlayback
    H.modify_ \s -> s { currentStep = 0, playback = Stopped }

  LoadResult mp ->
    H.modify_ \s -> s { process = mp, currentStep = 0, playback = Stopped, error = Nothing }

  LoadError err ->
    H.modify_ \s -> s { error = Just err }

  Tick -> do
    state <- H.get
    case state.playback of
      Playing ->
        if canStepForward state then
          H.modify_ \s -> s { currentStep = s.currentStep + 1 }
        else
          stopPlayback
      _ -> pure unit

startPlayback :: forall cs o m. MonadAff m => H.HalogenM AnimatorState Action cs o m Unit
startPlayback = do
  { emitter, listener } <- liftEffect HS.create
  timerRef <- liftEffect $ setInterval 2500 do
    HS.notify listener Tick
  void $ H.subscribe emitter
  H.modify_ \s -> s { playback = Playing, tickTimer = Just timerRef }

stopPlayback :: forall cs o m. MonadAff m => H.HalogenM AnimatorState Action cs o m Unit
stopPlayback = do
  state <- H.get
  case state.tickTimer of
    Just ref -> liftEffect $ clearInterval ref
    Nothing -> pure unit
  H.modify_ \s -> s { playback = Stopped, tickTimer = Nothing }

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
