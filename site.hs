--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll
import           Text.Pandoc
import           System.Directory (listDirectory, getCurrentDirectory, canonicalizePath, copyFile, removeFile)
import           System.FilePath ((</>))
import           Data.List.Split (splitOn)
import           FractalArt
import           Data.Maybe (fromMaybe)


--------------------------------------------------------------------------------
main :: IO ()
main = do
    -- Check for new blog posts and
    -- generate images
    generateBlogPostImages

    -- Compile hakyll static site
    compileStaticSite

writtenFiles :: [Maybe FilePath] -> [FilePath]
writtenFiles [] = []
writtenFiles (Nothing:xs) = writtenFiles xs
writtenFiles ((Just x):xs) = x : writtenFiles xs

imageNamesToGenerate :: [FilePath] -> [FilePath] -> [FilePath]
imageNamesToGenerate _ [] = []
imageNamesToGenerate ci (y:ys) 
    | y `elem` ci = imageNamesToGenerate ci ys
    | otherwise   = y : imageNamesToGenerate ci ys

imageNames :: [FilePath] -> [FilePath]
imageNames posts = extNames
    where noExtNames = getFileName <$> posts
          extNames = (++".png") <$> noExtNames

removeDSStore :: [FilePath] -> [FilePath]
removeDSStore []       = []
removeDSStore (x:xs)
    | x == ".DS_Store" = removeDSStore xs
    | otherwise        = x : removeDSStore xs

getFileName :: FilePath -> FilePath
getFileName = head . splitOn "."
    
writeHeaderImg :: FilePath -> FilePath -> IO (Maybe FilePath)
writeHeaderImg wd fp = do
    let filePath = wd </> fp
    postContents <- readFile filePath
    let fileName = getFileName fp
        postContentsList = lines postContents
        fourthLine = postContentsList !! 3
        -- TODO nbrk hack me
    if (fourthLine == "---") then do
        let headerImgLine = mconcat ["headerImg: ", fileName, ".png"]
            newContents = insertAt 2 headerImgLine postContentsList
            tempFile = wd </> "temp.markdown"
        _ <- writeFile tempFile $ unlines newContents
        _ <- copyFile tempFile filePath
        removeFile tempFile
        return $ Just fileName
    else return Nothing
        where insertAt :: Int -> String -> [String] -> [String]
              insertAt n s xs = fs ++ [s] ++ ls
                  where fs = take n xs
                        ls = drop n xs

generateBlogPostImages :: IO ()
generateBlogPostImages = do
    -- Fractal Art blog image generation
    pwd <- getCurrentDirectory

    let imageDirectory = pwd </> "static" </> "img/"
        postsDirectory = pwd </> "posts/"

    posts <- listDirectory postsDirectory
    allImages <- listDirectory imageDirectory
    let cleanedPosts = removeDSStore posts
        cleanedImages = removeDSStore allImages
        imgNames = imageNames cleanedPosts
        imgsToGen = imageNamesToGenerate cleanedImages imgNames

    -- Specify image names in each blog post markdown
    filesWrittenTo <- sequence $ (writeHeaderImg postsDirectory) <$> cleanedPosts

    -- Print which files were written to
    let writF = writtenFiles filesWrittenTo
    if length writF > 0 then do
        putStrLn "Wrote header images to the follows blog posts:"
        mapM_ print writF
        putStrLn ""
    else return ()

    -- Generate image if it doesn't exist
    let imgsToGenFps = (imageDirectory++) <$> imgsToGen
    sequence_ $ generateArt <$> imgsToGenFps

    -- Print which images were generated
    if length imgsToGenFps > 0 then do
        putStrLn "Generated the following images:"
        mapM_ print imgsToGen
        putStrLn ""
    else return ()

compileStaticSite :: IO () 
compileStaticSite = hakyll $ do
    match "static/*/*" $ do
        route idRoute
        compile copyFileCompiler

    match (fromList ["about.md", "contact.markdown", "projects.md"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/page.html" siteCtx
            >>= loadAndApplyTemplate "templates/default.html" siteCtx
            >>= relativizeUrls

    -- build up tags
    tags <- buildTags "posts/*.markdown" (fromCapture "tags/*.html")
    tagsRules tags $ \tag pattern -> do
        let title = "Posts tagged \"" ++ tag ++ "\""
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll pattern
            let ctx = constField "title" title
                      `mappend` listField "posts" postCtx (return posts)

                      `mappend` constField "baseurl" "http://nbrk.linklevel.net"
                      `mappend` constField "site_description" title
                      `mappend` constField "github_username" "nbrk"
                      `mappend` constField "tag" tag
                      `mappend` defaultContext
--                      `mappend` siteCtx
            makeItem ""
                >>= loadAndApplyTemplate "templates/tag.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls
                
    match "posts/*" $ do
      route $ setExtension "html"
      compile $ pandocCompiler
        >>= loadAndApplyTemplate "templates/post.html"    (postCtxWithTags tags)
        >>= loadAndApplyTemplate "templates/default.html" (postCtxWithTags tags)
        >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archive"             `mappend`
                    siteCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    -- create tag digest page
    create ["tags.html"] $ do
        route idRoute
        compile $ do
            let tagsCtx =
                  
--                  listField "tagsmap" postCtx (return (tagsMap tags)) `mappend`
                  tagCloudField "tagsfield" 100.0 300.0 tags `mappend`
                  constField "title" "Tags digest"          `mappend`
                  siteCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/tags.html" tagsCtx
                >>= loadAndApplyTemplate "templates/default.html" tagsCtx
                >>= relativizeUrls


    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Home"                `mappend`
                    siteCtx

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

    
    

--------------------------------------------------------------------------------
postCtxWithTags :: Tags -> Context String
postCtxWithTags tags = tagsField "tags" tags `mappend` postCtx

postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    siteCtx 

siteCtx :: Context String
siteCtx = 
    constField "baseurl" "http://nbrk.linklevel.net" `mappend` 
--    constField "baseurl" "http://127.0.0.1:8000" `mappend`
    constField "site_description" "/ Assorted crazy stuff / " `mappend`
    constField "github_username" "nbrk" `mappend`
    defaultContext
