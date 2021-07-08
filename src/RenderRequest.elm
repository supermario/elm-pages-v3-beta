module RenderRequest exposing
    ( IncludeHtml(..)
    , RenderRequest(..)
    , RequestPayload(..)
    , decoder
    , default
    , maybeRequestPayload
    )

import ApiRoute
import HtmlPrinter
import Internal.ApiRoute
import Json.Decode as Decode
import Json.Encode as Encode
import Pages.ProgramConfig exposing (ProgramConfig)
import Path exposing (Path)
import Regex
import Url exposing (Url)


type RequestPayload route
    = Page { path : Path, frontmatter : route }
    | Api ( String, ApiRoute.Done ApiRoute.Response )
    | NotFound Path


type RenderRequest route
    = SinglePage IncludeHtml (RequestPayload route) Decode.Value


default : RenderRequest route
default =
    SinglePage
        HtmlAndJson
        (NotFound (Path.fromString "/error"))
        Encode.null


maybeRequestPayload : RenderRequest route -> Maybe Decode.Value
maybeRequestPayload renderRequest =
    case renderRequest of
        SinglePage _ _ rawJson ->
            Just rawJson


type IncludeHtml
    = HtmlAndJson
    | OnlyJson


decoder :
    ProgramConfig userMsg userModel (Maybe route) siteData pageData sharedData
    -> Decode.Decoder (RenderRequest (Maybe route))
decoder config =
    Decode.field "request"
        (Decode.map3
            (\includeHtml requestThing payload ->
                SinglePage includeHtml requestThing payload
            )
            (Decode.field "kind" Decode.string
                |> Decode.andThen
                    (\kind ->
                        case kind of
                            "single-page" ->
                                Decode.field "jsonOnly" Decode.bool
                                    |> Decode.map
                                        (\jsonOnly ->
                                            if jsonOnly then
                                                OnlyJson

                                            else
                                                HtmlAndJson
                                        )

                            _ ->
                                Decode.fail "Unhandled"
                    )
            )
            (requestPayloadDecoder config)
            (Decode.field "payload" Decode.value)
        )



{-
   payload: modifiedRequest,
   kind: "single-page",
   jsonOnly: isJson,
-}


requestPayloadDecoder :
    ProgramConfig userMsg userModel (Maybe route) siteData pageData sharedData
    -> Decode.Decoder (RequestPayload (Maybe route))
requestPayloadDecoder config =
    (Decode.string
        |> Decode.map
            (\rawPath ->
                let
                    path : String
                    path =
                        rawPath
                            |> dropTrailingIndexHtml

                    route : Maybe route
                    route =
                        pathToUrl path |> config.urlToRoute

                    apiRoute : Maybe (ApiRoute.Done ApiRoute.Response)
                    apiRoute =
                        Internal.ApiRoute.firstMatch (String.dropLeft 1 path)
                            (config.apiRoutes HtmlPrinter.htmlToString)
                in
                case route of
                    Just _ ->
                        if isFile rawPath then
                            case apiRoute of
                                Just justApi ->
                                    ( path, justApi ) |> Api

                                Nothing ->
                                    NotFound (Path.fromString path)

                        else
                            Page
                                { frontmatter = route
                                , path = config.routeToPath route |> Path.join
                                }

                    Nothing ->
                        case apiRoute of
                            Just justApi ->
                                ( path, justApi ) |> Api

                            Nothing ->
                                NotFound (Path.fromString path)
            )
    )
        |> Decode.field "path"
        |> Decode.field "payload"


isFile : String -> Bool
isFile rawPath =
    rawPath
        |> String.contains "."


pathToUrl : String -> Url
pathToUrl path =
    { protocol = Url.Https
    , host = "TODO"
    , port_ = Nothing
    , path = path
    , query = Nothing
    , fragment = Nothing
    }


optionalField : String -> Decode.Decoder a -> Decode.Decoder (Maybe a)
optionalField fieldName decoder_ =
    let
        finishDecoding : Decode.Value -> Decode.Decoder (Maybe a)
        finishDecoding json =
            case Decode.decodeValue (Decode.field fieldName Decode.value) json of
                Ok _ ->
                    -- The field is present, so run the decoder_ on it.
                    Decode.map Just (Decode.field fieldName decoder_)

                Err _ ->
                    -- The field was missing, which is fine!
                    Decode.succeed Nothing
    in
    Decode.value
        |> Decode.andThen finishDecoding


dropTrailingIndexHtml : String -> String
dropTrailingIndexHtml =
    Regex.replace (Regex.fromString "/index\\.html$" |> Maybe.withDefault Regex.never)
        (\_ -> "")
