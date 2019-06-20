port module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes exposing (attribute, style)
import Json.Decode
import Svg
import Svg.Attributes exposing (fill, height, points, stroke, viewBox, width, x, y)


port dragEvents : (Json.Decode.Value -> msg) -> Sub msg


type alias Model =
    { polygon : Polygon
    , draggedVertex : Maybe Id
    }


type alias Polygon =
    Dict Id Coords


type alias Msg =
    { event : DragEvent
    , cursor : Coords
    , handlers : List ( Id, Rect )
    }


type DragEvent
    = Start
    | Move
    | Stop


type alias Coords =
    { x : Float, y : Float }


type alias Id =
    Int


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
    { polygon =
        Dict.fromList
            [ ( 0, Coords 10 20 )
            , ( 1, Coords 200 30 )
            , ( 2, Coords 190 300 )
            ]
    , draggedVertex = Nothing
    }



-- Update logic


update : Msg -> Model -> Model
update { event, cursor, handlers } model =
    case ( event, model.draggedVertex ) of
        ( Start, _ ) ->
            { model
                | draggedVertex =
                    handlers
                        |> List.filter
                            (\( _, handler ) ->
                                distance cursor (center handler) < 25
                            )
                        |> closestRect cursor
            }

        ( Move, Just id ) ->
            { model | polygon = Dict.insert id cursor model.polygon }

        ( Move, Nothing ) ->
            -- The user is dragging the cursor, but nothing was picked up on the
            -- start event. We'll sit this one out.
            model

        ( Stop, _ ) ->
            { model | draggedVertex = Nothing }



-- View logic


view : Model -> Browser.Document msg
view { polygon, draggedVertex } =
    { title = "Drag & Drop Example"
    , body =
        [ Svg.svg
            []
            ([ viewPolygon polygon
             ]
                ++ List.map viewHandle (Dict.toList polygon)
            )
        ]
    }


viewPolygon : Polygon -> Html msg
viewPolygon polygon =
    Svg.polygon
        [ fill "none"
        , stroke "black"
        , points
            (polygon
                |> Dict.values
                |> List.map (\{ x, y } -> String.fromFloat x ++ "," ++ String.fromFloat y)
                |> String.join " "
            )
        ]
        []


viewHandle : ( Id, Coords ) -> Html msg
viewHandle ( id, coords ) =
    let
        halfWidth : Float
        halfWidth =
            5
    in
    Svg.rect
        [ fill "none"
        , stroke "black"
        , x (String.fromFloat (coords.x - halfWidth))
        , y (String.fromFloat (coords.y - halfWidth))
        , width (String.fromFloat (2 * halfWidth))
        , height (String.fromFloat (2 * halfWidth))
        , attribute "data-beacon" (String.fromInt id)
        ]
        []



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
        (Json.Decode.field "beacons" handlersDecoder)


eventDecoder : Json.Decode.Decoder DragEvent
eventDecoder =
    Json.Decode.string
        |> Json.Decode.andThen
            (\eventType ->
                case eventType of
                    "start" ->
                        Json.Decode.succeed Start

                    "move" ->
                        Json.Decode.succeed Move

                    "stop" ->
                        Json.Decode.succeed Stop

                    _ ->
                        Json.Decode.fail ("Unknown drag event type " ++ eventType)
            )


coordsDecoder : Json.Decode.Decoder Coords
coordsDecoder =
    Json.Decode.map2 Coords
        (Json.Decode.field "x" Json.Decode.float)
        (Json.Decode.field "y" Json.Decode.float)


handlersDecoder : Json.Decode.Decoder (List ( Id, Rect ))
handlersDecoder =
    Json.Decode.list
        (Json.Decode.map2
            Tuple.pair
            (Json.Decode.field "id" Json.Decode.int)
            rectDecoder
        )


idDecoder : Json.Decode.Decoder Id
idDecoder =
    Json.Decode.string
        |> Json.Decode.andThen
            (\id ->
                case String.toInt id of
                    Just int ->
                        Json.Decode.succeed int

                    Nothing ->
                        Json.Decode.fail ("Could not decode as int: " ++ id)
            )


rectDecoder : Json.Decode.Decoder Rect
rectDecoder =
    Json.Decode.map4
        Rect
        (Json.Decode.field "x" Json.Decode.float)
        (Json.Decode.field "y" Json.Decode.float)
        (Json.Decode.field "width" Json.Decode.float)
        (Json.Decode.field "height" Json.Decode.float)



-- Functions for manipulating Rect's and Coords


closestRect : Coords -> List ( id, Rect ) -> Maybe id
closestRect cursor handlers =
    handlers
        |> List.map (Tuple.mapSecond (distance cursor << center))
        -- Find the vertex closest to the cursor.
        |> List.sortBy Tuple.second
        |> List.head
        |> Maybe.map Tuple.first


center : Rect -> Coords
center { x, y, width, height } =
    { x = x + (width / 2)
    , y = y + (height / 2)
    }


distance : Coords -> Coords -> Float
distance coords1 coords2 =
    let
        dx =
            coords1.x - coords2.x

        dy =
            coords1.y - coords2.y
    in
    sqrt ((dx ^ 2) + (dy ^ 2))
