{ mkDerivation, base, binary, bytestring, criterion, deepseq
, filepath, hedgehog, HUnit, optparse-applicative, parsec
, primitive, stdenv, tasty, tasty-discover, tasty-hedgehog
, tasty-hunit, temporary, text, transformers, vector
}:
mkDerivation {
  pname = "hbf";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    base binary bytestring deepseq filepath optparse-applicative parsec
    primitive text transformers vector
  ];
  executableHaskellDepends = [ base ];
  testHaskellDepends = [
    base hedgehog HUnit tasty tasty-discover tasty-hedgehog tasty-hunit
    temporary text transformers
  ];
  benchmarkHaskellDepends = [ base criterion text transformers ];
  license = stdenv.lib.licenses.gpl3;
}
