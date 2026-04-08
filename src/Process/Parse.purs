module Process.Parse where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Foldable (foldl)
import Data.Map as Map
import Data.Tuple (Tuple(..))
import Effect (Effect)
import FFI.Oxigraph (RdfQuad, parseQuads)
import Process.Types (Actor, Deadline, ProcessDef, Step, StepType(..))

-- | RDF namespace prefixes used in the process ontology
proc :: String
proc = "https://cardano-for-regulators.github.io/ontology/process#"

rdf :: String
rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

rdfs :: String
rdfs = "http://www.w3.org/2000/01/rdf-schema#"

-- | Parse a TTL string into a ProcessDef
parseTurtle :: String -> Effect (Maybe ProcessDef)
parseTurtle ttl = do
  quads <- parseQuads "text/turtle" proc ttl
  pure $ buildProcess quads

-- | Build a ProcessDef from parsed RDF quads
buildProcess :: Array RdfQuad -> Maybe ProcessDef
buildProcess quads =
  let
    -- Group quads by subject
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

    -- Find entities by rdf:type
    findByType :: String -> Array String
    findByType typ = Array.mapMaybe
      ( \(Tuple subj qs) ->
          if Array.any (\q -> q.predicate == rdf <> "type" && q.object.value == typ) qs then Just subj
          else Nothing
      )
      (Map.toUnfoldable grouped)

    -- Get a literal property value for a subject
    getProp :: String -> String -> Maybe String
    getProp subj prop =
      case Map.lookup subj grouped of
        Nothing -> Nothing
        Just qs -> map _.object.value $ Array.find (\q -> q.predicate == prop) qs

    -- Parse actors
    actorIds = findByType (proc <> "Actor")

    actors :: Array Actor
    actors = Array.mapWithIndex
      ( \i aid ->
          { id: aid
          , label: fromMaybe aid (getProp aid (rdfs <> "label"))
          , lane: i
          }
      )
      actorIds

    -- Parse steps
    stepIds = findByType (proc <> "Step")

    steps :: Array Step
    steps = Array.mapWithIndex
      ( \i sid ->
          { id: sid
          , label: fromMaybe sid (getProp sid (rdfs <> "label"))
          , description: getProp sid (rdfs <> "comment")
          , actor: fromMaybe "" (getProp sid (proc <> "actor"))
          , target: getProp sid (proc <> "target")
          , stepType: case getProp sid (proc <> "stepType") of
              Just v
                | v == proc <> "Transaction" -> Transaction
                | v == proc <> "OffChain" -> OffChain
                | v == proc <> "Query" -> Query
              _ -> OffChain
          , order: i
          }
      )
      stepIds

    -- Parse deadlines
    deadlineIds = findByType (proc <> "Deadline")

    deadlines :: Array Deadline
    deadlines = Array.mapMaybe
      ( \did ->
          case getProp did (proc <> "fromStep"), getProp did (proc <> "toStep") of
            Just from, Just to -> Just
              { label: fromMaybe "" (getProp did (rdfs <> "label"))
              , duration: fromMaybe "" (getProp did (proc <> "duration"))
              , fromStep: from
              , toStep: to
              }
            _, _ -> Nothing
      )
      deadlineIds

    -- Find the process itself
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
        }
