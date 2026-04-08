module Process.Types where

import Prelude
import Data.Maybe (Maybe(..))

type Actor =
  { id :: String
  , label :: String
  , lane :: Int
  }

data StepType
  = OnChain
  | OffChain

derive instance eqStepType :: Eq StepType

type DatumChange =
  { label :: String
  , field :: String
  , beforeValue :: String
  , afterValue :: String
  }

type SignatureReq =
  { label :: String
  , party :: String
  , sigType :: String
  }

type LifecycleState =
  { id :: String
  , label :: String
  , description :: Maybe String
  }

type Step =
  { id :: String
  , label :: String
  , narrative :: Maybe String
  , actor :: String
  , stepType :: StepType
  , order :: Int
  , fromState :: Maybe String
  , toState :: Maybe String
  , signatures :: Array SignatureReq
  , checks :: Array String
  , datumChanges :: Array DatumChange
  , action :: Maybe String
  }

type Deadline =
  { label :: String
  , duration :: String
  , fromState :: String
  , toState :: String
  }

type ProcessDef =
  { id :: String
  , label :: String
  , description :: Maybe String
  , actors :: Array Actor
  , steps :: Array Step
  , deadlines :: Array Deadline
  , lifecycleStates :: Array LifecycleState
  }

data PlaybackState
  = Stopped
  | Playing
  | Paused

derive instance eqPlaybackState :: Eq PlaybackState

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
