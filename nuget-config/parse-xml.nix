{ callPackage, fetchFromGitHub }:
let
  nix-parsec = fetchFromGitHub {
    owner = "Prunkles";
    repo = "nix-parsec";
    rev = "103832e0bd452e56216de6ad50a25af4ce436ff6";
    hash = "sha256-4EFCdqnXgxouLkTh1AM4HW9u7AvA7ATEiydg1H7qTMY=";
  };
  parseXml = (callPackage (import "${nix-parsec}/examples/xml/parse-xml.nix") {}).parseXml;
  uFEFF = "﻿"; # \uFEFF
in
text:
  let
    sanitizedText = builtins.replaceStrings [uFEFF] [""] text; # Because of BOM
  in
  parseXml sanitizedText

