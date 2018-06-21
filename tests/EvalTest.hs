module EvalTest where

import           Control.Monad.Trans.State (runStateT)
import           Data.Char                 (ord)
import           Data.Int                  (Int8)
import qualified Data.Text.Lazy.IO         as TIO
import qualified Data.Vector.Generic       as GV
import           Test.HUnit
import           Test.SmallCheck

import qualified HBF.Compiler              as C
import qualified HBF.Eval                  as E
import           HBF.Types
import           Helper

exec :: Program Optimized -> MockIO -> IO (E.TapeType, MockIO)
exec program = runStateT (E.eval program)

unit_canFactorNumbers :: Assertion
unit_canFactorNumbers = do
  code <- TIO.readFile "tests/factor.bf"
  let (Right (program, _)) = C.inMemoryCompile C.defaultCompilerOptions code
  (_, finalState) <- exec program (mkMockIOS "25454\n")
  mockOutputS finalState @?= "25454: 2 11 13 89\n"

unit_evalScanR :: Assertion
unit_evalScanR = do
  (tape, _) <- exec program (mkMockIO [])
  let (Tape mem index) = listTape tape
  (index, take 6 mem) @?= (4, [42, 42, 42, 42, 17, 0])
  where
    program -- evaluating should give [42,42,42,42,17,0,...]
     = Program [Inc 42 0, Mul 1 0 1, Mul 1 0 2, Mul 1 0 3, Scan Up 0, Inc 17 0]

unit_evalScanL :: Assertion
unit_evalScanL = do
  (tape, _) <- exec program (mkMockIO [])
  let (Tape mem index) = listTape tape
  (index, take 6 mem) @?= (1, [0, 17, 42, 42, 42, 0])
  where
    program -- evaluating should give [0,17,42,42,42,0,...]
     = Program [MRight 2, Inc 42 0, Mul 1 0 1, Mul 1 0 2, Scan Down 0, Inc 17 0]

unit_evalScanROnZero :: Assertion
unit_evalScanROnZero = do
  (tape, _) <- exec program (mkMockIO [])
  let (Tape mem index) = listTape tape
  (index, take 4 mem) @?= (1, [42, 0, 42, 0])
  where
    program -- evaluating should give [42,0,42,0,...]
     = Program [Inc 42 0, MRight 2, Inc 42 0, MRight (-1), Scan Up 0]

unit_evalScanLOnZero :: Assertion
unit_evalScanLOnZero = do
  (tape, _) <- exec program (mkMockIO [])
  let (Tape mem index) = listTape tape
  (index, take 4 mem) @?= (1, [42, 0, 42, 0])
  where
    program -- evaluating should give [42,0,42,0,...]
     = Program [Inc 42 0, MRight 2, Inc 42 0, MRight (-1), Scan Down 0]

-- todo: implement a property test starting with arbitrary memory
-- and evaluating ScanR and ScanL
scprop_allOptimizationFlagsSameResult :: CompFlags -> Property IO
scprop_allOptimizationFlagsSameResult (CompFlags opts) =
  monadic $ do
    code <- TIO.readFile "tests/allfeatures.bf"
    let (Right (program, _)) = C.inMemoryCompile opts code
    (finalTape, finalState) <- exec program (mkMockIOS "0")
    pure $
      mockOutputS finalState == expectedOutput &&
      memory finalTape == expectedMemory
  where
    expectedOutput = "AABFAq"
    expectedMemory =
      memory E.emptyTape GV.//
      zip [0 ..] [fromIntegral (ord '0' + ord 'A') :: Int8, 0, 0, 0, 1, 1, 70]
