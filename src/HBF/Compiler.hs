{-# LANGUAGE RecordWildCards #-}

module HBF.Compiler
  (
    BFP.ParseError
  , module HBF.Compiler
  )
where

import           Control.Monad        (when)
import qualified Data.Binary          as B
import           Data.ByteString.Lazy (ByteString)
import           Data.List            (group)
import           Data.Maybe           (fromMaybe)
import           Data.Semigroup       ((<>))
import Data.Text.Lazy    (Text)
import qualified Data.Text.Lazy.IO    as TIO
import           Options.Applicative

import qualified HBF.Parser           as BFP
import           HBF.Types

import           System.FilePath      ((-<.>))
import           System.Environment      (getArgs)

compilePToFile :: Program -> FilePath -> IO ()
compilePToFile = flip B.encodeFile

inMemoryCompile :: CompilerOptions -> Text -> (Either BFP.ParseError Program)
inMemoryCompile opts code =
  optimize opts <$> BFP.parseProgram code

compile :: CompilerOptions -> IO (Either BFP.ParseError Int)
compile opts@CompilerOptions{..} = do
  when cOptsVerbose $ do
    putStrLn "Compiler options:"
    print opts

  program <- inMemoryCompile opts <$> TIO.readFile cOptsSource

  either (return . Left) (\p -> compilePToFile p outPath >> return (Right $ length p)) program
  where
    outPath = fromMaybe (cOptsSource -<.> "bfc") cOptsOut

optimize :: CompilerOptions -> Program -> Program
optimize opts@CompilerOptions{..} p =
  if cOptsFusionOptimization
    then group p >>= crush
    else p

  where
    crush l@(Loop _:_) = map (\(Loop ops) -> Loop (optimize opts ops)) l
    crush l@(Inc:_)    = [IncN (length l)]
    crush l@(Dec:_)    = [DecN (length l)]
    crush l@(MLeft:_)  = [MLeftN (length l)]
    crush l@(MRight:_) = [MRightN (length l)]
    crush l@(In:_)     = [InN (length l)]
    crush l@(Out:_)    = [OutN (length l)]
    crush other        = other

load :: ByteString -> Program
load = B.decode

loadFile :: FilePath -> IO Program
loadFile = B.decodeFile

data CompilerOptions = CompilerOptions
  { cOptsOut                :: Maybe FilePath
  , cOptsFusionOptimization :: Bool
  , cOptsVerbose            :: Bool
  , cOptsSource             :: FilePath
  } deriving (Show)

optionsP :: Parser CompilerOptions
optionsP = CompilerOptions
  <$>
    optional (option str
    (long "output"
    <> short 'o'
    <> metavar "OUT"
    <> help "Compiled output path"))

  <*> flag True False
    ( long "disable-fusion-optimization"
    <> help "Disable fusion optimization (turn multiple + or > in a single operation)")

  <*> switch
    ( long "verbose"
    <> short 'v'
    <> help "Output more debugging information")

  <*> argument str
    (metavar "SRC"
    <> help "Input source code file")

options :: ParserInfo CompilerOptions
options = info (optionsP <**> helper)
  (fullDesc
  <> progDesc "Compile Brainfuck code in SRC file"
  <> header "An optimizing Brainfuck compiler and evaluator")

defaultCompilerOptions :: CompilerOptions
defaultCompilerOptions = CompilerOptions {
    cOptsOut = Nothing
  , cOptsFusionOptimization = True
  , cOptsVerbose = False
  , cOptsSource = ""
  }

noOptimizationCompilerOptions :: CompilerOptions
noOptimizationCompilerOptions = CompilerOptions {
    cOptsOut = Nothing
  , cOptsFusionOptimization = False
  , cOptsVerbose = False
  , cOptsSource = ""
  }

parsePure :: [String] -> ParserResult CompilerOptions
parsePure = execParserPure defaultPrefs options

unsafeParse :: [String] -> IO CompilerOptions
unsafeParse = handleParseResult . parsePure

parse :: IO CompilerOptions
parse = getArgs >>= unsafeParse
