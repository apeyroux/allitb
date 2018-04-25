{ mkDerivation, base, bytestring, HandsomeSoup, http-conduit
, http-types, hxt, mtl, regex-compat, stdenv
}:
mkDerivation {
  pname = "allitbs";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    base bytestring HandsomeSoup http-conduit http-types hxt mtl
    regex-compat
  ];
  homepage = "https://github.com/githubuser/allitbs#readme";
  license = stdenv.lib.licenses.bsd3;
}
