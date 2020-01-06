module RssFeed exposing (Item, generate)

import Date exposing (Date)
import Dict
import Imf.DateTime
import Time
import Xml
import Xml.Encode exposing (..)


type alias Item =
    { title : String
    , description : String
    , url : String
    , categories : List String
    , author : String
    , pubDate : Date
    , content : Maybe String

    {-
       lat optional number The latitude coordinate of the item.
       long optional number The longitude coordinate of the item.
       custom_elements optional array Put additional elements in the item (node-xml syntax)
       enclosure optional object An enclosure object
    -}
    }


generate :
    { title : String
    , description : String
    , url : String
    , lastBuildTime : Time.Posix
    , generator :
        Maybe
            { name : String
            , uri : Maybe String
            , version : Maybe String
            }
    , items : List Item
    , siteUrl : String
    }
    -> Xml.Value
generate feed =
    object
        [ ( "rss"
          , Dict.fromList
                [ ( "xmlns:dc", string "http://purl.org/dc/elements/1.1/" )
                , ( "xmlns:content", string "http://purl.org/rss/1.0/modules/content/" )
                , ( "xmlns:atom", string "http://www.w3.org/2005/Atom" )
                , ( "version", string "2.0" )
                ]
          , object
                [ ( "channel"
                  , Dict.empty
                  , list
                        ([ keyValue "title" feed.title
                         , keyValue "description" feed.description
                         , keyValue "link" feed.url
                         , keyValue "lastBuildDate" <| Imf.DateTime.fromPosix Time.utc feed.lastBuildTime
                         ]
                            ++ List.map (itemXml feed.siteUrl) feed.items
                            ++ ([ feed.generator |> Maybe.map generatorXml
                                ]
                                    |> List.filterMap identity
                               )
                        )
                  )
                ]
          )
        ]


itemXml : String -> Item -> Xml.Value
itemXml siteUrl item =
    object
        [ ( "item"
          , Dict.empty
          , list
                ([ keyValue "title" item.title
                 , keyValue "description" item.description
                 , keyValue "link" (siteUrl ++ item.url)
                 , keyValue "guid" (siteUrl ++ item.url)
                 , keyValue "pubDate" (formatDate item.pubDate)
                 ]
                    ++ ([ item.content |> Maybe.map (\content -> keyValue "content" content)
                        ]
                            |> List.filterMap identity
                       )
                )
          )
        ]


formatDate : Date -> String
formatDate date =
    Date.format "EEE, dd MMM yyyy" date
        ++ " 00:00:00 UTC"


generatorXml :
    { name : String
    , uri : Maybe String
    , version : Maybe String
    }
    -> Xml.Value
generatorXml generator =
    Xml.Encode.object
        [ ( "generator"
          , [ generator.uri |> Maybe.map (\uri -> ( "uri", string uri ))
            , generator.version |> Maybe.map (\version -> ( "version", string version ))
            ]
                |> List.filterMap identity
                |> Dict.fromList
          , Xml.Encode.string generator.name
          )
        ]


keyValue : String -> String -> Xml.Value
keyValue key value =
    object [ ( key, Dict.empty, string value ) ]
