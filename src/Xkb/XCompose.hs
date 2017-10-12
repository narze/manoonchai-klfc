{-# LANGUAGE UnicodeSyntax, NoImplicitPrelude #-}

module Xkb.XCompose where

import BasePrelude
import Prelude.Unicode
import Data.Monoid.Unicode ((⊕))
import Util (ifNonEmpty, escape, privateChars, versionStr)

import Control.Monad.State (evalState)
import Control.Monad.Writer (runWriter)
import Lens.Micro.Platform (view, over, _1)

import Layout.DeadKey (actionMapToStringMap)
import Layout.Types
import Xkb.General (setNullChars)
import Xkb.Symbols (printLetter)

printXCompose ∷ Layout → Maybe String
printXCompose = flip evalState privateChars ∘ setNullChars >>> \layout → do
    let layouts = layout : map variantToLayout (view _variants layout)
    let body =
         ifNonEmpty ([]:) (concatMap printLigatures layouts) ⧺
         concatMap printCustomDeadKeys layouts
    guard (not (null body))
    pure ∘ unlines $
        [ "# Generated by KLFC " ⊕ versionStr
        , "# https://github.com/39aldo39/klfc"
        ] ⧺ body

printLigatures ∷ Layout → [String]
printLigatures = concatMap (mapMaybe printLigature ∘ view _letters) ∘ view _keys

printLigature ∷ Letter → Maybe String
printLigature (Ligature (Just c) xs) = Just (printCombination [Char c] xs)
printLigature _ = Nothing

printCustomDeadKeys ∷ Layout → [String]
printCustomDeadKeys = concatMap (concatMap printCustomDeadKey ∘ view _letters) ∘ view _keys

printCustomDeadKey ∷ Letter → [String]
printCustomDeadKey (CustomDead _ (DeadKey name (Just c) actionMap)) =
    [] : "# Dead key: " ⊕ name : printCombinations (map (over _1 (Char c :)) (actionMapToStringMap actionMap))
printCustomDeadKey _ = []

printCombinations ∷ [([Letter], String)] → [String]
printCombinations = map (uncurry printCombination)

printCombination ∷ [Letter] → String → String
printCombination xs s = concatMap (\c → "<" ⊕ printKeysym c ⊕ "> ") xs ⊕ ": " ⊕ escape s
  where printKeysym = fst ∘ runWriter ∘ printLetter
