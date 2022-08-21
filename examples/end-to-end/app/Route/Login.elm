module Route.Login exposing (ActionData, Data, Model, Msg, route)

import DataSource exposing (DataSource)
import ErrorPage exposing (ErrorPage)
import Form
import Form.Field as Field
import Form.FieldView
import Form.Validation as Validation exposing (Combined)
import Head
import Head.Seo as Seo
import Html.Styled as Html exposing (Html)
import Html.Styled.Attributes as Attr
import MySession
import Pages.Msg
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Route
import RouteBuilder exposing (StatefulRoute, StatelessRoute, StaticPayload)
import Server.Request as Request
import Server.Response as Response exposing (Response)
import Server.Session as Session
import Shared
import View exposing (View)


type alias Model =
    {}


type alias Msg =
    ()


type alias RouteParams =
    {}


type alias ActionData =
    { errors : Form.Response String
    }


route : StatelessRoute RouteParams Data ActionData
route =
    RouteBuilder.serverRender
        { head = head
        , data = data
        , action =
            \_ ->
                MySession.withSession
                    (Request.formDataWithServerValidation [ form ])
                    (\nameResultData session ->
                        nameResultData
                            |> DataSource.map
                                (\nameResult ->
                                    case nameResult of
                                        Err errors ->
                                            ( session
                                                |> Result.withDefault Nothing
                                                |> Maybe.withDefault Session.empty
                                            , Response.render
                                                { errors = errors
                                                }
                                            )

                                        Ok ( _, name ) ->
                                            ( session
                                                |> Result.withDefault Nothing
                                                |> Maybe.withDefault Session.empty
                                                |> Session.insert "name" name
                                                |> Session.withFlash "message" ("Welcome " ++ name ++ "!")
                                            , Route.redirectTo Route.Greet
                                            )
                                )
                    )
        }
        |> RouteBuilder.buildNoState { view = view }


type alias Data =
    { username : Maybe String
    , flashMessage : Maybe String
    }


form : Form.DoneForm String (DataSource (Combined String String)) data (List (Html (Pages.Msg.Msg Msg)))
form =
    Form.init
        (\username ->
            { combine =
                Validation.succeed identity
                    |> Validation.andMap username
                    |> Validation.map
                        (\clientValidated ->
                            DataSource.succeed
                                (Validation.succeed clientValidated
                                    |> Validation.withErrorIf
                                        (clientValidated == "error")
                                        username
                                        "Invalid username"
                                )
                        )
            , view =
                \formState ->
                    let
                        errors : Validation.Field String parsed kind -> List String
                        errors field =
                            formState.errors
                                |> Form.errorsForField field

                        errorsView : Validation.Field String parsed kind -> Html msg
                        errorsView field =
                            case
                                ( formState.submitAttempted
                                , errors field
                                )
                            of
                                ( _, first :: rest ) ->
                                    Html.div []
                                        [ Html.ul
                                            [ Attr.style "border" "solid red"
                                            ]
                                            (List.map
                                                (\error ->
                                                    Html.li []
                                                        [ Html.text error
                                                        ]
                                                )
                                                (first :: rest)
                                            )
                                        ]

                                _ ->
                                    Html.div [] []

                        fieldView : String -> Validation.Field String parsed Form.FieldView.Input -> Html msg
                        fieldView label field =
                            Html.div []
                                [ Html.label []
                                    [ Html.text (label ++ " ")
                                    , field |> Form.FieldView.inputStyled []
                                    ]
                                , errorsView field
                                ]
                    in
                    [ fieldView "Username" username
                    , Html.button []
                        [ (if formState.isTransitioning then
                            "Logging in..."

                           else
                            "Log in"
                          )
                            |> Html.text
                        ]
                    ]
            }
        )
        |> Form.field "name" (Field.text |> Field.required "Required")


data : RouteParams -> Request.Parser (DataSource (Response Data ErrorPage))
data routeParams =
    Request.oneOf
        [ MySession.withSession
            (Request.succeed ())
            (\() session ->
                case session of
                    Ok (Just okSession) ->
                        let
                            flashMessage : Maybe String
                            flashMessage =
                                okSession
                                    |> Session.get "message"
                        in
                        ( okSession
                        , Data
                            (okSession |> Session.get "name")
                            flashMessage
                            |> Response.render
                        )
                            |> DataSource.succeed

                    _ ->
                        ( Session.empty
                        , { username = Nothing, flashMessage = Nothing }
                            |> Response.render
                        )
                            |> DataSource.succeed
            )
        ]


head :
    StaticPayload Data ActionData RouteParams
    -> List Head.Tag
head static =
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


view :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data ActionData RouteParams
    -> View (Pages.Msg.Msg Msg)
view maybeUrl sharedModel static =
    { title = "Login"
    , body =
        [ static.data.flashMessage
            |> Maybe.map (\message -> flashView (Ok message))
            |> Maybe.withDefault (Html.p [] [ Html.text "No flash" ])
        , Html.p []
            [ Html.text
                (case static.data.username of
                    Just username ->
                        "Hello " ++ username ++ "!"

                    Nothing ->
                        "You aren't logged in yet."
                )
            ]
        , form
            |> Form.toDynamicTransition "form"
            |> Form.renderStyledHtml []
                (static.action |> Maybe.map .errors |> Maybe.map (\(Form.Response response) -> response))
                static
                ()
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
