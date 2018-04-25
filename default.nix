{ nixpkgs ? import <nixpkgs> {}, compiler ? "ghc841" }:

nixpkgs.pkgs.haskell.packages.${compiler}.callPackage ./allitb.nix { }
