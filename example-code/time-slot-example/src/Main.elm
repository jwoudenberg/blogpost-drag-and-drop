port module Main exposing (main)

import Array exposing (Array)
import Browser
import Html exposing (Attribute, Html)
import Html.Attributes exposing (attribute, style)
import Json.Decode


port dragEvents : (Json.Decode.Value -> msg) -> Sub msg


{-| In this example a time slot always covers whole hours,
but we could make this minutes or seconds if we wanted.
-}
type alias Model =
    { selectionStart : Hour, selectionEnd : Hour }


type alias Hour =
    Int


type alias Msg =
    { event : DragEvent
    , cursor : Coords
    , sliderPosition : Rect
    }


type DragEvent
    = Start
      -- We don't need to do anything special on a Stop event, so we can treat
      -- it the same as a Move event.
    | MoveOrStop


type alias Coords =
    { x : Float, y : Float }


type alias Rect =
    { x : Float, y : Float, width : Float, height : Float }


main : Program () Model Msg
main =
    Browser.document
        { init = \_ -> ( init, Cmd.none )
        , view = view
        , update = \msg model -> ( update msg model, Cmd.none )
        , subscriptions = \_ -> dragEvents decodeDragEvents
        }


init : Model
init =
    { selectionStart = 0, selectionEnd = 0 }



-- Update logic


update : Msg -> Model -> Model
update msg model =
    let
        hour =
            cursorAtHour msg
    in
    case msg.event of
        Start ->
            if coordsInRect msg.cursor msg.sliderPosition then
                { selectionStart = hour
                , selectionEnd = hour
                }

            else
                model

        MoveOrStop ->
            { model
                | selectionEnd = hour
            }


cursorAtHour : Msg -> Hour
cursorAtHour { cursor, sliderPosition } =
    let
        dx =
            cursor.x - sliderPosition.x

        atMost =
            min

        atLeast =
            max
    in
    (24 * (dx / sliderPosition.width))
        |> floor
        -- Ensure we get a number between 0 and 23, even if the cursor moves to
        -- the left or right of the slider.
        |> atMost 23
        |> atLeast 0



-- View logic


view : Model -> Browser.Document msg
view model =
    { title = "Drag & Drop Example"
    , body =
        [ Html.div
            [ attribute "data-beacon" "slider"
            , style "position" "fixed"
            , style "top" "40vh"
            , style "left" "10vw"
            , style "height" "20px"
            , style "width" "80vw"
            , style "border" "1px solid black"
            ]
            [ viewHourLabels
            , viewTimeSlot model
            ]
        ]
    }


viewTimeSlot : Model -> Html msg
viewTimeSlot { selectionStart, selectionEnd } =
    Html.div
        [ style "position" "absolute"
        , style "top" "0"
        , style "left" (viewPercentage (percentageOfDay (min selectionStart selectionEnd)))
        , style "width" (viewPercentage (percentageOfDay (1 + abs (selectionEnd - selectionStart))))
        , style "height" "100%"
        , style "background-color" "black"
        ]
        []


percentageOfDay : Hour -> Float
percentageOfDay hour =
    (toFloat hour * 100) / 24


viewPercentage : Float -> String
viewPercentage percentage =
    String.fromFloat percentage ++ "%"


viewHourLabels : Html msg
viewHourLabels =
    Html.div
        ([ style "display" "flex"
         , style "height" "100%"
         , style "width" "100%"
         ]
            ++ userSelectNone
        )
        (List.range 1 24
            |> List.map viewHourLabel
        )


userSelectNone : List (Attribute msg)
userSelectNone =
    List.map (\key -> style key "none")
        [ "-webkit-touch-callout"
        , "-webkit-user-select"
        , "-khtml-user-select"
        , "-moz-user-select"
        , "-ms-user-select"
        , "user-select"
        ]


viewHourLabel : Int -> Html msg
viewHourLabel hour =
    Html.div
        [ style "width" "1%"
        , style "flex-grow" "1"
        , style "position" "relative"
        , style "top" "-100%"
        , style "height" "200%"
        , style "text-align" "right"
        ]
        [ Html.text (String.fromInt hour)
        ]



-- Json Decoders


decodeDragEvents : Json.Decode.Value -> Msg
decodeDragEvents value =
    case Json.Decode.decodeValue msgDecoder value of
        Ok msg ->
            msg

        Err err ->
            -- A real Elm application might log errors for developers or store
            -- them on the model so they can be shown to the user. We'll forgo
            -- that here to allow for a smaller example, more focused on the
            -- drag & drop aspects of the application.
            Debug.todo "Implement error handling."


msgDecoder : Json.Decode.Decoder Msg
msgDecoder =
    Json.Decode.map3 Msg
        (Json.Decode.field "type" eventDecoder)
        (Json.Decode.field "cursor" coordsDecoder)
        (Json.Decode.field "beacons" sliderPositionDecoder)


eventDecoder : Json.Decode.Decoder DragEvent
eventDecoder =
    Json.Decode.string
        |> Json.Decode.andThen
            (\eventType ->
                case eventType of
                    "start" ->
                        Json.Decode.succeed Start

                    "move" ->
                        Json.Decode.succeed MoveOrStop

                    "stop" ->
                        Json.Decode.succeed MoveOrStop

                    _ ->
                        Json.Decode.fail ("Unknown drag event type " ++ eventType)
            )


coordsDecoder : Json.Decode.Decoder Coords
coordsDecoder =
    Json.Decode.map2 Coords
        (Json.Decode.field "x" Json.Decode.float)
        (Json.Decode.field "y" Json.Decode.float)


sliderPositionDecoder : Json.Decode.Decoder Rect
sliderPositionDecoder =
    Json.Decode.field "0" rectDecoder


rectDecoder : Json.Decode.Decoder Rect
rectDecoder =
    Json.Decode.map4
        Rect
        (Json.Decode.field "x" Json.Decode.float)
        (Json.Decode.field "y" Json.Decode.float)
        (Json.Decode.field "width" Json.Decode.float)
        (Json.Decode.field "height" Json.Decode.float)



-- Functions for manipulating Rect's and Coords


distance : Coords -> Coords -> Float
distance coords1 coords2 =
    let
        dx =
            coords1.x - coords2.x

        dy =
            coords1.y - coords2.y
    in
    sqrt ((dx ^ 2) + (dy ^ 2))


coordsInRect : Coords -> Rect -> Bool
coordsInRect coords rect =
    (coords.x >= rect.x)
        && (coords.x <= (rect.x + rect.width))
        && (coords.y >= rect.y)
        && (coords.y <= (rect.y + rect.height))
