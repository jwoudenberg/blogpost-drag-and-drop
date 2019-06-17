port module Main exposing (main)

import Array exposing (Array)
import Browser
import Browser.Events
import Html exposing (Attribute, Html)
import Html.Attributes exposing (attribute, style)
import Html.Events as Events
import Json.Decode
import Json.Encode


port dragEvents : (Json.Decode.Value -> msg) -> Sub msg


type alias Model =
    { outline : List OutlineNode
    , draggedNode : Maybe DraggedNode
    }


type alias DraggedNode =
    { node : String
    , cursorOnScreen : Coords
    , cursorOnDraggable : Coords
    }


type Msg
    = Start DraggedNode
    | Move DragMsg
    | Stop


type alias DragMsg =
    { cursor : Coords
    , beacons : List Beacon
    }


type alias Beacon =
    ( CandidatePosition, Rect )


type alias OutlineNode =
    Tree String


type Tree a
    = Tree
        { node : a
        , children : List (Tree a)
        }


type CandidatePosition
    = Before String
    | After String
    | PrependedIn String
    | AppendedIn String


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
        , subscriptions =
            \_ ->
                Sub.batch
                    [ Browser.Events.onMouseUp (Json.Decode.succeed Stop)
                    , dragEvents decodeDragEvents
                    ]
        }


init : Model
init =
    { outline =
        [ Tree
            { node = "root"
            , children =
                [ Tree { node = "child1", children = [] }
                , Tree
                    { node = "child2"
                    , children =
                        [ Tree { node = "grandchild", children = [] }
                        ]
                    }
                ]
            }
        ]
    , draggedNode = Nothing
    }



-- Update logic


update : Msg -> Model -> Model
update msg model =
    case msg of
        Start draggedNode ->
            { model
                | draggedNode = Just draggedNode
            }

        Move dragMsg ->
            case model.draggedNode of
                Nothing ->
                    model

                Just draggedNode ->
                    { model
                        | draggedNode = Just { draggedNode | cursorOnScreen = dragMsg.cursor }
                        , outline = updateOutline draggedNode dragMsg model.outline
                    }

        Stop ->
            { model | draggedNode = Nothing }


updateOutline : DraggedNode -> DragMsg -> List OutlineNode -> List OutlineNode
updateOutline { node, cursorOnDraggable } { cursor, beacons } outline =
    case closestRect (subtractCoords cursor cursorOnDraggable) beacons of
        Nothing ->
            outline

        Just position ->
            moveNodeInOutline node position outline


moveNodeInOutline : String -> CandidatePosition -> List OutlineNode -> List OutlineNode
moveNodeInOutline draggedNode position outline =
    if positionBase position == draggedNode then
        outline

    else
        let
            found : Maybe OutlineNode
            found =
                List.filterMap (findNode draggedNode) outline
                    |> List.head

            afterRemoving : List OutlineNode
            afterRemoving =
                List.filterMap (removeNode draggedNode) outline
        in
        case found of
            Nothing ->
                outline

            Just foundNode ->
                let
                    { insertSucceeded, resultTrees } =
                        insertNode position foundNode afterRemoving
                in
                if insertSucceeded then
                    resultTrees

                else
                    outline


removeNode : a -> Tree a -> Maybe (Tree a)
removeNode target (Tree tree) =
    if target == tree.node then
        Nothing

    else
        Just (Tree { tree | children = List.filterMap (removeNode target) tree.children })


findNode : a -> Tree a -> Maybe (Tree a)
findNode target (Tree tree) =
    if target == tree.node then
        Just (Tree tree)

    else
        List.filterMap (findNode target) tree.children
            |> List.head


{-| Insert a node in a tree. You need to tell this function where to insert the
node relative to some other node. If that other node cannot be found, the insert
operation will fail.
-}
insertNode :
    CandidatePosition
    -> Tree String
    -> List (Tree String)
    -> { insertSucceeded : Bool, resultTrees : List (Tree String) }
insertNode position toInsert trees =
    case trees of
        [] ->
            { insertSucceeded = False
            , resultTrees = []
            }

        (Tree tree) :: tail ->
            if positionBase position == tree.node then
                { insertSucceeded = True
                , resultTrees =
                    case position of
                        Before _ ->
                            toInsert :: Tree tree :: tail

                        After _ ->
                            Tree tree :: toInsert :: tail

                        PrependedIn _ ->
                            Tree { tree | children = toInsert :: tree.children } :: tail

                        AppendedIn _ ->
                            Tree { tree | children = tree.children ++ [ toInsert ] } :: tail
                }

            else
                let
                    afterInsertChildren =
                        insertNode position toInsert tree.children

                    afterInsertTail =
                        insertNode position toInsert tail
                in
                { insertSucceeded = afterInsertChildren.insertSucceeded || afterInsertTail.insertSucceeded
                , resultTrees = Tree { tree | children = afterInsertChildren.resultTrees } :: afterInsertTail.resultTrees
                }


positionBase : CandidatePosition -> String
positionBase position =
    case position of
        Before text ->
            text

        After text ->
            text

        PrependedIn text ->
            text

        AppendedIn text ->
            text



-- View logic


view : Model -> Browser.Document Msg
view model =
    { title = "Drag & Drop Example"
    , body =
        [ viewOutline (Maybe.map .node model.draggedNode) model.outline
        , viewDraggedNode model
        ]
    }


viewDraggedNode : Model -> Html Msg
viewDraggedNode model =
    let
        draggedNode =
            Maybe.andThen (findOutlineNode model.outline << .node) model.draggedNode

        draggedCoords =
            Maybe.map .cursorOnScreen model.draggedNode
    in
    case ( draggedNode, model.draggedNode ) of
        ( Just node, Just { cursorOnScreen, cursorOnDraggable } ) ->
            Html.ul
                [ style "position" "fixed"
                , style "top" (String.fromFloat (cursorOnScreen.y - cursorOnDraggable.y) ++ "px")
                , style "left" (String.fromFloat (cursorOnScreen.x - cursorOnDraggable.x) ++ "px")
                , style "list-style" "none"
                , style "padding" "0"
                , style "margin" "0"
                ]
                [ viewNodeWithoutBeacons node ]

        _ ->
            Html.text ""


findOutlineNode : List (Tree a) -> a -> Maybe (Tree a)
findOutlineNode nodes text =
    nodes
        |> List.filterMap (findNode text)
        |> List.head


viewOutline : Maybe String -> List OutlineNode -> Html Msg
viewOutline draggedNode outline =
    Html.ul
        [ style "list-style" "circle" ]
        (List.map (viewNode draggedNode) outline)


viewNode : Maybe String -> OutlineNode -> Html Msg
viewNode draggedNode (Tree tree) =
    if draggedNode == Just tree.node then
        Html.div [ style "opacity" "0.5" ]
            [ viewNodeWithoutBeacons (Tree tree) ]

    else
        Html.div
            []
            [ viewBeacon (Before tree.node)
            , Html.li
                []
                [ viewNodeText tree.node
                , Html.ul [ style "list-style" "circle" ]
                    (viewBeacon (PrependedIn tree.node)
                        :: List.map (viewNode draggedNode) tree.children
                        ++ [ viewBeacon (AppendedIn tree.node) ]
                    )
                ]
            , viewBeacon (After tree.node)
            ]


viewNodeWithoutBeacons : OutlineNode -> Html Msg
viewNodeWithoutBeacons (Tree { node, children }) =
    Html.div
        []
        [ Html.li
            []
            [ viewNodeText node
            , Html.ul [ style "list-style" "circle" ]
                (List.map viewNodeWithoutBeacons children)
            ]
        ]


viewNodeText : String -> Html Msg
viewNodeText text =
    let
        onPointerDown : Attribute Msg
        onPointerDown =
            Events.on "pointerdown"
                (Json.Decode.map2
                    (\cursorOnScreen cursorOffset ->
                        Start
                            { node = text
                            , cursorOnScreen = cursorOnScreen
                            , cursorOnDraggable = cursorOffset
                            }
                    )
                    cursorPositionDecoder
                    cursorOffsetDecoder
                )
    in
    Html.span
        (onPointerDown :: userSelectNone)
        [ Html.text text ]


cursorPositionDecoder : Json.Decode.Decoder Coords
cursorPositionDecoder =
    Json.Decode.map2 Coords
        (Json.Decode.field "clientX" Json.Decode.float)
        (Json.Decode.field "clientY" Json.Decode.float)


cursorOffsetDecoder : Json.Decode.Decoder Coords
cursorOffsetDecoder =
    Json.Decode.map2 Coords
        (Json.Decode.field "offsetX" Json.Decode.float)
        (Json.Decode.field "offsetY" Json.Decode.float)


viewBeacon : CandidatePosition -> Html msg
viewBeacon position =
    let
        positionValue =
            encodePosition position
    in
    Html.span
        [ attribute "data-beacon" (Json.Encode.encode 0 positionValue)
        , style "font-size" "0"
        ]
        []


encodePosition : CandidatePosition -> Json.Encode.Value
encodePosition position =
    let
        ( positionStr, textStr ) =
            case position of
                Before text ->
                    ( "before", text )

                After text ->
                    ( "after", text )

                PrependedIn text ->
                    ( "prepended-in", text )

                AppendedIn text ->
                    ( "appended-in", text )
    in
    Json.Encode.object
        [ ( "position", Json.Encode.string positionStr )
        , ( "text", Json.Encode.string textStr )
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


type NodeOrBeacon
    = Node ( String, Rect )
    | Beacon ( CandidatePosition, Rect )


msgDecoder : Json.Decode.Decoder Msg
msgDecoder =
    Json.Decode.map2
        (\cursor beacons -> Move (DragMsg cursor beacons))
        (Json.Decode.field "cursor" coordsDecoder)
        (Json.Decode.field "beacons" (Json.Decode.list beaconDecoder))


coordsDecoder : Json.Decode.Decoder Coords
coordsDecoder =
    Json.Decode.map2 Coords
        (Json.Decode.field "x" Json.Decode.float)
        (Json.Decode.field "y" Json.Decode.float)


beaconDecoder : Json.Decode.Decoder Beacon
beaconDecoder =
    Json.Decode.map2
        Tuple.pair
        (Json.Decode.field "id" positionInOutlineDecoder)
        rectDecoder


positionInOutlineDecoder : Json.Decode.Decoder CandidatePosition
positionInOutlineDecoder =
    Json.Decode.map2
        Tuple.pair
        (Json.Decode.field "position" Json.Decode.string)
        (Json.Decode.field "text" Json.Decode.string)
        |> Json.Decode.andThen toPosition


toPosition : ( String, String ) -> Json.Decode.Decoder CandidatePosition
toPosition ( position, text ) =
    case position of
        "before" ->
            Json.Decode.succeed (Before text)

        "after" ->
            Json.Decode.succeed (After text)

        "prepended-in" ->
            Json.Decode.succeed (PrependedIn text)

        "appended-in" ->
            Json.Decode.succeed (AppendedIn text)

        _ ->
            Json.Decode.fail ("Unknown position: " ++ position)


rectDecoder : Json.Decode.Decoder Rect
rectDecoder =
    Json.Decode.map4
        Rect
        (Json.Decode.field "x" Json.Decode.float)
        (Json.Decode.field "y" Json.Decode.float)
        (Json.Decode.field "width" Json.Decode.float)
        (Json.Decode.field "height" Json.Decode.float)


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


subtractCoords : Coords -> Coords -> Coords
subtractCoords coords1 coords2 =
    { x = coords1.x - coords2.x
    , y = coords1.y - coords2.y
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
