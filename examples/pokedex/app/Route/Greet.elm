module Route.Greet exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import ErrorPage exposing (ErrorPage)
import FatalError exposing (FatalError)
import Head
import Head.Seo as Seo
import Html exposing (Html)
import Html.Attributes as Attr
import MySession
import Pages.Url
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatelessRoute)
import Server.Request as Request exposing (Parser)
import Server.Response exposing (Response)
import Server.Session as Session
import Shared
import Time
import View exposing (View)


type alias Model =
    {}


type alias Msg =
    ()


type alias RouteParams =
    {}


route : StatelessRoute RouteParams Data ActionData
route =
    RouteBuilder.serverRender
        { head = head
        , data = data
        , action = \_ -> Request.skip "No action."
        }
        |> RouteBuilder.buildNoState { view = view }


data : RouteParams -> Request.Parser (BackendTask FatalError (Response Data ErrorPage))
data routeParams =
    Request.oneOf
        [ Request.map2 (\a b -> Data a b Nothing)
            (Request.expectQueryParam "name")
            Request.requestTime
            |> Request.map
                (\requestData ->
                    requestData
                        |> Server.Response.render
                        |> Server.Response.withHeader
                            "x-greeting"
                            ("hello there " ++ requestData.username ++ "!")
                        |> BackendTask.succeed
                )
        , Request.requestTime
            |> MySession.expectSessionOrRedirect
                (\requestTime session ->
                    let
                        username : String
                        username =
                            session
                                |> Session.get "name"
                                |> Maybe.withDefault "NONAME"

                        flashMessage : Maybe String
                        flashMessage =
                            session
                                |> Session.get "message"
                    in
                    ( session
                    , { username = username
                      , requestTime = requestTime
                      , flashMessage = flashMessage
                      }
                        |> Server.Response.render
                        |> Server.Response.withHeader
                            "x-greeting"
                            ("hello " ++ username ++ "!")
                    )
                        |> BackendTask.succeed
                )
        ]


head :
    App Data ActionData RouteParams
    -> List Head.Tag
head app =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "elm-pages"
        , image =
            { url = Pages.Url.external "TODO"
            , alt = "elm-pages logo"
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = "TODO"
        , locale = Nothing
        , title = "TODO title" -- metadata.title -- TODO
        }
        |> Seo.website


type alias Data =
    { username : String
    , requestTime : Time.Posix
    , flashMessage : Maybe String
    }


type alias ActionData =
    {}


view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> View (PagesMsg Msg)
view app shared =
    { title = "Hello!"
    , body =
        [ app.data.flashMessage
            |> Maybe.map (\message -> flashView (Ok message))
            |> Maybe.withDefault (Html.p [] [ Html.text "No flash" ])
        , Html.text <| "Hello " ++ app.data.username ++ "!"
        , Html.text <| "Requested page at " ++ String.fromInt (Time.posixToMillis app.data.requestTime)
        , Html.div []
            [ Html.form
                [ Attr.method "post"
                , Attr.action "/api/logout"
                ]
                [ Html.button
                    [ Attr.type_ "submit"
                    ]
                    [ Html.text "Logout" ]
                ]
            ]
        ]
    }


flashView : Result String String -> Html msg
flashView message =
    Html.p
        [ Attr.style "background-color" "rgb(163 251 163)"
        ]
        [ Html.text <|
            case message of
                Ok okMessage ->
                    okMessage

                Err error ->
                    "Something went wrong: " ++ error
        ]
