{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Control.Exception as E
import           Control.Exception as X
import qualified Data.ByteString.Lazy as BL
import           Data.ByteString.Lazy.Char8 (pack)
import           Network.HTTP.Conduit
import           Network.HTTP.Types.Status
import           System.Environment
import           Text.HandsomeSoup
import           Text.Regex
import           Text.XML.HXT.Core

main :: IO ()
main = do
  args <- getArgs
  case args of
    [s] -> do
        pages <- runX $ (doc "1" s) >>> css "span[class=pages]" >>> getChildren >>> getText
        case pages of
          [] -> do
            dwlBooksInPage "1" s
          jpages -> do
            mapM_ (\x-> case (matchRegex rxNbPages x) of
                      Just [nbp] -> do
                        mapM_ (\p -> do
                                  --  putStrLn $ "Traitement de la page " ++ show p
                                  dwlBooksInPage (show p) s
                              ) [1..(read nbp::Int)]
                      Nothing -> putStrLn "no pagination ..."
                      _ -> usage
              ) jpages
    _ -> usage
  where
    usage = putStrLn "Usage:\n\tallitb haskell"
    rxNbPages = mkRegex "1 / (.+?) Pages"
    dwlBooksInPage p s = do
      links <- runX $ doc p s >>> css "h2"
               >>> css "a"
               >>> ((deep getText) &&& getAttrValue "href")
      mapM_ (\(t, l) -> do
                urlpdf <- runX $ fromUrl l
                  >>> css "span[class=download-links]"
                  >>> getChildren
                  >>> css "a"
                  >>> getAttrValue "href"
                printdwl t
                case urlpdf of
                  [urlpdf, _] -> simpleHttp urlpdf `E.catch` (\(HttpExceptionRequest _ ex) -> do
                                                                 putStrLn (show ex)
                                                                 return $ pack $ show ex) >>= BL.writeFile (t ++ ".pdf")
                  otherwise -> printerr t
            ) links
    doc p s = fromUrl ("http://www.allitebooks.com/page/" ++ p ++ "/?s=" ++ s)
    printerr t = putStrLn $ "[err] I cant find book url (" ++ t ++ ") url ..."
    printdwl t = putStrLn $ "[dwl] " ++ t ++ " ..."