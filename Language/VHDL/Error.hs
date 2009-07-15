-----------------------------------------------------------------------------
-- |
-- Module      :  Language.VHDL.Error
-- Copyright   :  (c) SAM Group, KTH/ICT/ECS 2007-2008
-- License     :  BSD-style (see the file LICENSE)
-- 
-- Maintainer  :  christiaan.baaij@gmail.com
-- Stability   :  experimental
-- Portability :  portable
--
-- ForSyDe error-related types and functions.
--
-----------------------------------------------------------------------------
module Language.VHDL.Error 
 (VHDLErr(..),
  EProne,
  module Control.Monad.Error,
  module Debug.Trace) where

import Debug.Trace
import Control.Monad.Error 

-------------
-- VHDLErr
-------------

-- | All Errors thrown or displayed in ForSyDe
data VHDLErr = 
  -- Used in ForSyDe.Backend.VHDL.*
  -- | Empty VHDL identifier
  EmptyVHDLId                                |
  -- | Incorrect Basic VHDL Identifier
  IncVHDLBasId String                        |
  -- | Incorrect Extended VHDL Identifier
  IncVHDLExtId String                        |
  -- | Other Errors
  Other String

-- | Show errors
instance Show VHDLErr where
 show EmptyVHDLId = "Empty VHDL identifier"
 show (IncVHDLBasId id)  = "Incorrect VHDL basic identifier " ++ 
                           "`" ++ id ++ "'"
 show (IncVHDLExtId id)  = "Incorrect VHDL extended identifier " ++ 
                           "`" ++ id ++ "'"

--------------
-- Error Monad
--------------

-- | We make CLasHErr an instance of the Error class to be able to throw it
-- as an exception.
instance Error VHDLErr where
 noMsg  = Other "An Error has ocurred"
 strMsg = Other

-- | 'EProne' represents failure using Left CLasHErr  or a successful 
--   result of type a using Right a
-- 
--  'EProne' is implicitly an instance of 
--   ['MonadError']  (@Error e => MonadError e (Either e)@)
--   ['Monad']       (@Error e => Monad (Either e)@)
type EProne = Either VHDLErr
-- FIXME: Rethink Eprone so that it takes contexts in account
