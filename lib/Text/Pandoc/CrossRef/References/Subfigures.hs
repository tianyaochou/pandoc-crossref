
module Text.Pandoc.CrossRef.References.Subfigures where

-- import Text.Pandoc.Definition
-- import qualified Text.Pandoc.Builder as B
-- import Text.Pandoc.Shared (stringify, hierarchicalize, Element(..))
-- import Control.Monad.State hiding (get, modify)
-- import Data.List
-- import Data.Maybe
-- import Data.Monoid
-- import qualified Data.Map as M
--
-- import Data.Accessor.Monad.Trans.State
-- import Text.Pandoc.CrossRef.References.Types
-- import Text.Pandoc.CrossRef.Util.Util
-- import Text.Pandoc.CrossRef.Util.Options
-- import Text.Pandoc.CrossRef.Util.Prefixes
-- import Text.Pandoc.CrossRef.Util.Template
-- import Text.Pandoc.CrossRef.Util.CodeBlockCaptions
-- import Control.Applicative
-- import Data.Default (def)
-- import Prelude
--
-- replaceBlock opts scope (Div (label,cls,attrs) images)
--   | Just pfx <- getRefPrefix opts label
--   , Para caption <- last images
--   = do
--     idxStr <- replaceAttr opts scope (Right label) (lookup "label" attrs) (B.fromList caption) pfx
--     let (cont, st) = runState (runReplace scope (mkRR $ replaceSubfigs opts') $ init images) def
--         collectedCaptions = B.toList $
--             intercalate' (ccsDelim opts)
--           $ map (collectCaps . snd)
--           $ sortOn (refIndex . snd)
--           $ filter (not . null . refTitle . snd)
--           $ M.toList
--           $ referenceData_ st
--         collectCaps v =
--               applyTemplate
--                 (chapPrefix (chapDelim opts) (refIndex v))
--                 (refTitle v)
--                 (ccsTemplate opts)
--         vars = M.fromDistinctAscList
--                   [ ("ccs", B.fromList collectedCaptions)
--                   , ("i", idxStr)
--                   , ("t", B.fromList caption)
--                   ]
--         capt = applyTemplate' vars $ pfxCaptionTemplate opts pfx
--         opts' = opts {
--             prefixes = case M.lookup ("sub" <> pfx) $ prefixes opts of
--               Just sp -> M.insert pfx sp $ prefixes opts
--               Nothing -> prefixes opts
--             }
--     lastRef <- fromJust . M.lookup label <$> get referenceData
--     modify referenceData $ \old ->
--         M.union
--           old
--           (M.map (\v -> v{refIndex = refIndex lastRef, refSubfigure = Just $ refIndex v})
--           $ referenceData_ st)
--     case outFormat opts of
--           f | isLatexFormat f, pfx == "fig" ->
--             replaceNoRecurse $ Div nullAttr $
--               [ RawBlock (Format "latex") "\\begin{figure}\n\\centering" ]
--               ++ cont ++
--               [ Para [RawInline (Format "latex") "\\caption"
--                        , Span nullAttr caption]
--               , RawBlock (Format "latex") $ mkLaTeXLabel label
--               , RawBlock (Format "latex") "\\end{figure}"]
--           _  -> replaceNoRecurse $ Div (label, "subfigures":cls, attrs) $ toTable cont capt
--   where
--     toTable :: [Block] -> B.Inlines -> [Block]
--     toTable blks capt
--       | subfigGrid opts = [Table [] align widths [] $ map blkToRow blks, mkCaption opts "Image Caption" capt]
--       | otherwise = blks ++ [mkCaption opts "Image Caption" capt]
--       where
--         align | Para ils:_ <- blks = replicate (length $ mapMaybe getWidth ils) AlignCenter
--               | otherwise = error "Misformatted subfigures block"
--         widths | Para ils:_ <- blks
--                = fixZeros $ mapMaybe getWidth ils
--                | otherwise = error "Misformatted subfigures block"
--         getWidth (Image (_id, _class, as) _ _)
--           = Just $ maybe 0 percToDouble $ lookup "width" as
--         getWidth _ = Nothing
--         fixZeros :: [Double] -> [Double]
--         fixZeros ws
--           = let nz = length $ filter (== 0) ws
--                 rzw = (0.99 - sum ws) / fromIntegral nz
--             in if nz>0
--                then map (\x -> if x == 0 then rzw else x) ws
--                else ws
--         percToDouble :: String -> Double
--         percToDouble percs
--           | '%' <- last percs
--           , perc <- read $ init percs
--           = perc/100.0
--           | otherwise = error "Only percent allowed in subfigure width!"
--         blkToRow :: Block -> [[Block]]
--         blkToRow (Para inls) = mapMaybe inlToCell inls
--         blkToRow x = [[x]]
--         inlToCell :: Inline -> Maybe [Block]
--         inlToCell (Image (id', cs, as) txt tgt)  = Just [Para [Image (id', cs, setW as) txt tgt]]
--         inlToCell _ = Nothing
--         setW as = ("width", "100%"):filter ((/="width") . fst) as
--
-- replaceSubfigs :: Options -> Scope -> [Inline] -> WS (ReplacedResult [Inline])
-- replaceSubfigs opts scope = (replaceNoRecurse scope . concat =<<) . mapM (replaceSubfig opts)
--
-- replaceSubfig :: Options -> Inline -> WS [Inline]
-- replaceSubfig opts x@(Image (label,cls,attrs) alt (src, tit))
--   = do
--       let label' | "fig:" `isPrefixOf` label = Right label
--                  | null label = Left "fig"
--                  | otherwise  = Right $ "fig:" ++ label
--       let ialt = B.fromList alt
--       idxStr <- replaceAttr opts scope label' (lookup "label" attrs) ialt "fig"
--       case outFormat opts of
--         f | isLatexFormat f ->
--           return $ latexSubFigure x label
--         _  ->
--           let alt' = B.toList $ applyTemplate idxStr ialt $ pfxCaptionTemplate opts "fig"
--               tit' | "nocaption" `elem` cls = fromMaybe tit $ stripPrefix "fig:" tit
--                    | "fig:" `isPrefixOf` tit = tit
--                    | otherwise = "fig:" ++ tit
--           in return [Image (label, cls, attrs) alt' (src, tit')]
-- replaceSubfig _ x = return [x]
-- latexSubFigure :: Inline -> String -> [Inline]
-- latexSubFigure (Image (_, cls, attrs) alt (src, title)) label =
--   let
--     title' = fromMaybe title $ stripPrefix "fig:" title
--     texlabel | null label = []
--              | otherwise = [RawInline (Format "latex") $ mkLaTeXLabel label]
--     texalt | "nocaption" `elem` cls  = []
--            | otherwise = concat
--               [ [ RawInline (Format "latex") "["]
--               , alt
--               , [ RawInline (Format "latex") "]"]
--               ]
--     img = Image (label, cls, attrs) alt (src, title')
--   in concat [
--       [ RawInline (Format "latex") "\\subfloat" ]
--       , texalt
--       , [Span nullAttr $ img:texlabel]
--       ]
-- latexSubFigure x _ = [x]