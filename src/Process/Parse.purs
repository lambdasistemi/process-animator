module Process.Parse where

import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Foldable (foldl)
import Data.Map as Map
import Data.String.Pattern (Pattern(..))
import Data.String.Common (split) as Str
import Data.Tuple (Tuple(..))
import Effect (Effect)
import FFI.Oxigraph (RdfQuad, parseQuads)
import Process.Types (Actor, Deadline, DatumChange, LifecycleState, ProcessDef, SignatureReq, Step, StepType(..))

proc :: String
proc = "https://lambdasistemi.github.io/cardano-for-regulators/ontology/process#"

cfr :: String
cfr = "https://lambdasistemi.github.io/cardano-for-regulators/ontology#"

rdf :: String
rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

rdfs :: String
rdfs = "http://www.w3.org/2000/01/rdf-schema#"

parseTurtle :: String -> Effect (Maybe ProcessDef)
parseTurtle ttl = do
  quads <- parseQuads "text/turtle" proc ttl
  pure $ buildProcess quads

type Grouped = Map.Map String (Array RdfQuad)

buildProcess :: Array RdfQuad -> Maybe ProcessDef
buildProcess quads =
  let
    grouped :: Grouped
    grouped = foldl
      ( \acc q ->
          Map.alter
            ( case _ of
                Nothing -> Just [ q ]
                Just qs -> Just (Array.snoc qs q)
            )
            q.subject
            acc
      )
      Map.empty
      quads

    findByType :: String -> Array String
    findByType typ = Array.mapMaybe
      ( \(Tuple subj qs) ->
          if Array.any (\q -> q.predicate == rdf <> "type" && q.object.value == typ) qs then Just subj
          else Nothing
      )
      (Map.toUnfoldable grouped)

    getProp :: String -> String -> Maybe String
    getProp subj p =
      case Map.lookup subj grouped of
        Nothing -> Nothing
        Just qs -> map _.object.value $ Array.find (\q -> q.predicate == p) qs

    getProps :: String -> String -> Array String
    getProps subj p =
      case Map.lookup subj grouped of
        Nothing -> []
        Just qs -> map _.object.value $ Array.filter (\q -> q.predicate == p) qs

    -- Actors: collect unique actor URIs from steps, resolve labels
    actorUris = Array.nub $ Array.mapMaybe (\sid -> getProp sid (proc <> "actor")) stepIds

    actors :: Array Actor
    actors = Array.mapWithIndex
      ( \i aid ->
          { id: aid
          , label: fromMaybe (stripUri aid) (getProp aid (rdfs <> "label"))
          , lane: i
          }
      )
      actorUris

    -- Steps: OnChainStep + OffChainStep, sorted by proc:stepOrder
    onChainIds = findByType (proc <> "OnChainStep")
    offChainIds = findByType (proc <> "OffChainStep")
    stepIds = onChainIds <> offChainIds

    parseStep :: String -> Step
    parseStep sid =
      let
        isOnChain = Array.elem sid onChainIds
        order = case getProp sid (proc <> "stepOrder") of
          Just v -> fromMaybe 0 (Int.fromString v)
          Nothing -> 0

        sigRefs = getProps sid (proc <> "requiresSig")
        sigs = Array.mapMaybe parseSig sigRefs

        checkRefs = getProps sid (proc <> "checks")

        changeRefs = getProps sid (proc <> "changes")
        changes = Array.mapMaybe parseDatumChange changeRefs
      in
        { id: sid
        , label: fromMaybe (stripUri sid) (getProp sid (rdfs <> "label"))
        , narrative: getProp sid (proc <> "narrative")
        , actor: fromMaybe "" (getProp sid (proc <> "actor"))
        , stepType: if isOnChain then OnChain else OffChain
        , order
        , fromState: getProp sid (proc <> "fromState")
        , toState: getProp sid (proc <> "toState")
        , signatures: sigs
        , checks: checkRefs
        , datumChanges: changes
        , action: getProp sid (proc <> "usesAction")
        }

    steps :: Array Step
    steps = Array.sortWith _.order $ map parseStep stepIds

    parseSig :: String -> Maybe SignatureReq
    parseSig uri = case getProp uri (rdfs <> "label") of
      Nothing -> Nothing
      Just lbl -> Just
        { label: lbl
        , party: fromMaybe "" (getProp uri (proc <> "sigParty"))
        , sigType: fromMaybe "" (getProp uri (proc <> "sigType"))
        }

    parseDatumChange :: String -> Maybe DatumChange
    parseDatumChange uri = case getProp uri (rdfs <> "label") of
      Nothing -> Nothing
      Just lbl -> Just
        { label: lbl
        , field: fromMaybe "" do
            fieldUri <- getProp uri (proc <> "changesField")
            getProp fieldUri (proc <> "fieldName")
        , beforeValue: fromMaybe "" (getProp uri (proc <> "beforeValue"))
        , afterValue: fromMaybe "" (getProp uri (proc <> "afterValue"))
        }

    -- Deadlines
    deadlineIds = findByType (proc <> "Deadline")

    deadlines :: Array Deadline
    deadlines = Array.mapMaybe
      ( \did ->
          case getProp did (proc <> "deadlineFrom"), getProp did (proc <> "deadlineTo") of
            Just from, Just to -> Just
              { label: fromMaybe "" (getProp did (rdfs <> "label"))
              , duration: fromMaybe "" (getProp did (proc <> "slotDuration"))
              , fromState: from
              , toState: to
              }
            _, _ -> Nothing
      )
      deadlineIds

    -- Lifecycle states
    stateIds = findByType (cfr <> "LifecycleState")

    lifecycleStates :: Array LifecycleState
    lifecycleStates = map
      ( \sid ->
          { id: sid
          , label: fromMaybe (stripUri sid) (getProp sid (rdfs <> "label"))
          , description: getProp sid (rdfs <> "comment")
          }
      )
      stateIds

    processIds = findByType (proc <> "Process")
  in
    case Array.head processIds of
      Nothing -> Nothing
      Just pid -> Just
        { id: pid
        , label: fromMaybe "Process" (getProp pid (rdfs <> "label"))
        , description: getProp pid (rdfs <> "comment")
        , actors
        , steps
        , deadlines
        , lifecycleStates
        }

stripUri :: String -> String
stripUri uri =
  let
    parts = Str.split (Pattern "#") uri
    afterHash = fromMaybe uri (Array.last parts)
    segments = Str.split (Pattern "/") afterHash
  in
    fromMaybe afterHash (Array.last segments)
