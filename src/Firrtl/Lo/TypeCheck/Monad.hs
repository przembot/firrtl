module Firrtl.Lo.TypeCheck.Monad
  ( Check (..)
  -- re-exports
  , get
  , modify
  , put
  , throwError

  -- classes
  , Typed (..)

  -- Context
  , Context (..)
  , insert
  , lookup
  , singleton
  , delete

  -- Errors
  , Error (..)

  -- misc
  , cataM
  ) where

import           Prelude             hiding (lookup)
import           Control.Monad              ((>=>))
import           Control.Monad.Except       (MonadError (..))
import           Control.Monad.State        (MonadState (..), modify)
import           Control.Monad.Identity     (Identity (..))
import           Control.Monad.Trans        (lift)
import           Control.Monad.Trans.Except (ExceptT)
import           Control.Monad.Trans.State  (StateT)

import           Data.Functor.Foldable
import           Data.HashMap.Strict (HashMap)
import qualified Data.HashMap.Strict as Map
-- import           Data.Kind (type (*))
import           Data.Semigroup      (Semigroup (..))
import           Data.Width

import qualified Numeric.Natural     as N

import           Firrtl.Lo.Syntax
import           Firrtl.Lo.TypeCheck.Ty

data Error
  = ExpectedGround RTy
  | ExpectedGroundInt RTy
  | ExpectedParameter RTy
  | Mismatch RTy RTy
  | NodeMale RTy
  | NotInScope Id (Maybe RTy)
  | NoTopModule Id
  | ParameterToBig N.Natural RTy
  | Connectable RTy RTy
  | Containable RTy RTy
  | Equivalent RTy RTy
  | NotEnoughWidth Literal Width
  deriving Show

-- | Context associate identifiers with type
--   wich should be sufficient information
--   during typechecking phase
newtype Context t = Ctx { unCtx :: HashMap Id t }
  deriving (Functor, Traversable, Foldable, Semigroup, Monoid)

singleton :: Id -> t -> Context t
singleton ident = Ctx . Map.singleton ident

insert :: Id -> t -> Context t -> Context t
insert ident ty (Ctx m) = Ctx (Map.insert ident ty m)

lookup :: Id -> Context t -> Maybe t
lookup ident (Ctx m) = Map.lookup ident m

delete :: Id -> Context t -> Context t
delete ident (Ctx m) = Ctx (Map.delete ident m)

-- Should we go ReaderT and mutate it's context?
-- Check { runCheck :: ExceptT Error (ReaderT Context IO) a }
-- https://www.fpcomplete.com/blog/2017/07/the-rio-monad
newtype Check a =
  Check { runCheck :: ExceptT Error (StateT (Context RTy) Identity) a }
    deriving
      ( Functor
      , Applicative
      , Monad
      )

deriving instance (ErrorType Check ~ Error) => MonadError Check
-- deriving instance (StateType Check ~ Context) => MonadState Check

instance MonadState Check where
  type StateType Check = Context RTy
  get = Check $ lift $ get
  put = Check . lift . put

class Typed ast where
  -- type TypeFor ast
  type TypeSafe ast

--   hasType  :: TypeFor ast -> Check ()
--   typeOf   :: ast -> Check (TypeFor ast)
  typeSafe :: ast -> Check (TypeSafe ast)

cataM :: (Traversable (Base t), Monad m, Recursive t) => (Base t c -> m c) -> t -> m c
cataM = cata . (sequence >=>)
