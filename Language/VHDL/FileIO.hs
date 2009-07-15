-----------------------------------------------------------------------------
-- |
-- Module      :  Language.VHDL.FileIO
-- Copyright   :  (c) SAM Group, KTH/ICT/ECS 2007-2008
-- License     :  BSD-style (see the file LICENSE)
-- 
-- Maintainer  :  forsyde-dev@ict.kth.se
-- Stability   :  experimental
-- Portability :  portable
--
-- Functions working with files in the VHDL backend. 
--
-----------------------------------------------------------------------------
module Language.VHDL.FileIO (writeDesignFile) where

import Language.VHDL.AST
import Language.VHDL.AST.Ppr() -- instances
import qualified Language.VHDL.Ppr as Ppr (ppr)

import System.IO
import Text.PrettyPrint.HughesPJ

-- | Write a design file to a file in disk
writeDesignFile :: DesignFile -> FilePath -> IO ()
writeDesignFile df fp = do
  handle     <- openFile fp WriteMode
  hPutStrLn handle "-- Automatically generated VHDL"
  hPutStr handle $ (renderStyle mystyle . Ppr.ppr) df
  hClose handle
 where mystyle = style{lineLength=80, ribbonsPerLine=1}
