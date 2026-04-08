module Process.Types where

import Prelude
import Data.Maybe (Maybe(..))

-- | An actor participating in a process (e.g. Controller, Chain, SA)
type Actor =
  { id :: String
  , label :: String
  , lane :: Int -- visual lane position (0 = left, 1 = center, 2 = right, ...)
  }

-- | A single step in a process
type Step =
  { id :: String
  , label :: String
  , description :: Maybe String
  , actor :: String -- actor id who initiates
  , target :: Maybe String -- target actor id (e.g. Chain for transactions)
  , stepType :: StepType
  , order :: Int
  }

-- | What kind of step this is
data StepType
  = Transaction -- on-chain transaction
  | OffChain -- off-chain activity
  | Query -- read-only query

derive instance eqStepType :: Eq StepType

-- | A deadline constraint on a process
type Deadline =
  { label :: String
  , duration :: String -- e.g. "PT72H", "P1M"
  , fromStep :: String -- step id
  , toStep :: String -- step id
  }

-- | A complete process definition parsed from RDF
type ProcessDef =
  { id :: String
  , label :: String
  , description :: Maybe String
  , actors :: Array Actor
  , steps :: Array Step
  , deadlines :: Array Deadline
  }

-- | Animation playback state
data PlaybackState
  = Stopped
  | Playing
  | Paused

derive instance eqPlaybackState :: Eq PlaybackState

-- | The current state of the animator
type AnimatorState =
  { process :: Maybe ProcessDef
  , currentStep :: Int
  , playback :: PlaybackState
  , error :: Maybe String
  }

initialState :: AnimatorState
initialState =
  { process: Nothing
  , currentStep: 0
  , playback: Stopped
  , error: Nothing
  }
