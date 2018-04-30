{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Control.Exception as E
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as C8
import qualified Data.ByteString.Lazy as BL
import           Data.Monoid
import           Network.HTTP.Conduit
import           Network.HTTP.Types.Status
import           Options.Applicative
import System.Directory
import           System.IO.Error
import           Text.HandsomeSoup
import           Text.Regex
import           Text.XML.HXT.Core

data OptArgs = OptArgs {
  optArgsQuery :: String
  , optArgsDestination :: String
  }

optArgs :: Parser OptArgs
optArgs = OptArgs
          <$> strOption (long "search" <> short 'q')
          <*> strOption (long "destination" <> short 'd')

allitb :: OptArgs -> IO ()
allitb (OptArgs query dest) = do
  pages <- runX $ (doc "1" query) >>> css "span[class=pages]" >>> getChildren >>> getText
  case pages of
    [] -> do
      dwlBooksInPage "1" query
    jpages -> do
      mapM_ (\x-> case (matchRegex rxNbPages x) of
                Just [nbp] -> do
                  mapM_ (\p -> do
                            --  putStrLn $ "Traitement de la page " ++ show p
                            dwlBooksInPage (show p) query
                        ) [1..(read nbp::Int)]
                Nothing -> putStrLn "no pagination ..."
                _ -> putStrLn "usage"
        ) jpages
  where
    rxNbPages = mkRegex "1 / (.+?) Pages"
    dwlBooksInPage p q = do
      links <- runX $ doc p q >>> css "h2"
               >>> css "a"
               >>> ((deep getText) &&& getAttrValue "href")
      mapM_ (\(t, l) -> do
                urlpdf <- runX $ fromUrl l
                  >>> css "span[class=download-links]"
                  >>> getChildren
                  >>> css "a"
                  >>> getAttrValue "href"
                case urlpdf of
                  [pdf, _] -> simpleHttp pdf `E.catch` (\(HttpExceptionRequest _ ex) -> do
                                                           case ex of
                                                             StatusCodeException r _ -> do
                                                               C8.putStrLn $ C8.pack "[err] "
                                                                 <> (statusMessage $ responseStatus r)
                                                                 <> C8.pack " with book "
                                                                 <> C8.pack t
                                                               return $ BL.pack $ B.unpack $ statusMessage $ responseStatus r
                                                             _ -> return $ BL.pack $ B.unpack $ "dwl ok"
                                                       )
                                 >>= (\raw -> printdwl t >> return raw)
                                 >>= (\raw -> catchIOError (createDirectoryIfMissing True dest
                                                            >> BL.writeFile (dest ++ "/" ++ t ++ ".pdf") raw)
                                              (\ioerr -> print ioerr)
                                     )
                  _ -> putStrLn "no url found for this pdf ..."
            ) links
    doc p s = fromUrl ("http://www.allitebooks.com/page/" ++ p ++ "/?s=" ++ s)
    printdwl t = putStrLn $ "[dwl] " ++ t ++ " ..."

main :: IO ()
main = allitb =<< execParser opts
  where
    opts = info (optArgs <**> helper)
      ( fullDesc
     <> progDesc "Siphon AllitBooks")
