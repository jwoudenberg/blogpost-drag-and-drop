# Drag & Drop without Draggables & Dropzones

Drag & drop UIs have been around for a while, and so you would be forgiven for thinking they're a solved problem. Certainly there's high quality libraries to help us build drag & drop UIs, and these days we even have an official HTML5 drag & drop API! Why then is building drag & drop UIs so hard?

Having built some drag & drop UIs I've come to the conclusion a big part of the problem is our choice of tools. Those tools are the draggables and dropzones most libraries provide for building drag & drop interactions. Not using draggables & dropzones to build UIs often simplifies their construction massively.

That's a pretty sweeping statement for a broad term like 'drag & drop', so I'd better back it up! To do so I'll show you three examples of drag & drop UIs built without draggables or dropzones. These examples come from real projects, but I've simplified them for this blog post. I'll include what I believe to be the most relevant code snippets in those post, and invite you to look at the full source code if you'd like to learn more!

With all that said, let's start with a quick refresher on draggables and dropzones.

## A Refresher on Draggables & Dropzones

Draggables and dropzones form the core API of most drag & drop libraries, but what are they? Lets look at Trello, a web application in which draggables and dropzones are easy to identify. In Trello you can drag cards between columns. This makes cards draggables and columns dropzones.

On closer inspection though, things aren't as clear cut. For example, when you miss a dropzone by dragging next to a column and releasing it you might expect that card to return to its original column, or even get lost. But what happens is that the card will land in the column nearest to where you released. That's a nicer user experience, but implementing it using draggables and dropzones gets complicated.

## Our first example, A Timeslot Selector

Our first example is a UI for selecting a time slot in a day. This UI represents a day as a horizontal bar, in which you can select a slot using drag & drop.

![Selecting a time slot by drag & drop][slider.gif]

I'd like to start these examples by what a draggables + dropzones implementation might look like. Right of the bat we run into trouble, because it's unclear what our draggables and dropzones are. If we wanted to we could make the time slider the draggable since clicking anywhere in it should start the drag operation, even if we don't drag the time slider itself. The screen as a whole might serve as a dropzone, because the user should be able to release the cursor anywhere. We can try this and hope our trickery will fly (well, drag), or we can try take a more direct approach.

Lets start things in a way we often do in Elm: by designing our Model. Its simple, because our application needs to store a time slot which is nothing more than a start and end hour.

```elm
-- In this example a time slot always covers whole hours,
-- but we could make this minutes or seconds if we wanted.
type alias Model =
    { from : Hour, until : Hour }

type alias Hour =
    Int
```

Now for the drag & drop behavior. To keep the example simple we'll focus on support for dragging from the left to the right. This means that when the user presses down we store the hour the cursor is over as the left bound of the time slot. Then as the cursor moves to the right we will update the `until` time of the timeslot, until the user releases.

We can calculate the hour the cursor is over if we know the position of both the cursor and the time slider on the screen. Lets optimistically design a `Msg` type containing this information.

```elm
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
```

When we get a `Msg` like this, we can calculate the hour the cursor is over.

```elm
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
```

All that's left to do is use this in our `update` function. When we get a `Start` event we update the `from` field in the model, and when we get a `MoveOrStop` event the `to` field.

```elm
update : Msg -> Model -> Model
update msg model =
    let
        hour =
            cursorAtHour msg
    in
    case msg.event of
        Start ->
            if coordsInRect msg.cursor msg.sliderPosition then
                { from = hour
                , until = hour + 1
                }

            else
                model

        MoveOrStop ->
            { model
                | until = 1 + max hour model.from
            }

coordsInRect : Coords -> Rect -> Bool
coordsInRect =
    Debug.todo "Implementation omitted for brevity."
```

I've skipped over the JavaScript code required to send drag events to the Elm code. We'll talk more about that in a bit. I've also skipped over the Elm application that frames this drag & drop code.
You can find the full example online.

## Second example, a polygon editor

Our second example is a tool for drawing polygons. For this example we'll work on moving the vertices of an existing polygon. When pressing down we'd like to grab the closest vertex within 50 pixels of the cursor. That vertex should then follow the cursor until the user releases it.

![Dragging a vertex of a polygon][polygon.gif]

This example looks like a better use for draggables & dropzones than the previous one. You see those vertices? Those sure look like draggables! The problem here is that the vertices are small and hard to miss, so we'll want draggables to be bigger. We could achieve this by making the draggables be invisible `div` elements drawn around the vertices, but that approach breaks down when the `div` elements are close enough to overlap. At that point a click won't select the closest vertex but the vertex higher in the stacking order.

Lets leave those draggables in the toolbox and see how far we get without them. As usual we start by defining some types. We'll need to store the polygon we're editing,

```elm
type alias Model =
    { polygon : Polygon
    , draggedVertex : Maybe Id
    }

type alias Polygon =
    Array Coords

type alias Id =
    Int
```

We're using array indices as id's for the vertices of the polygon. Not a great solution in general, but it makes a bunch of update logic super simple allowing us to focus on the drag & drop aspects of the problem!

To find the vertex closest to the cursor we need the positions of the cursor and all vertices. Lets create a `Msg` type that contains both. We can reuse the `Coords` and `Rect` types from the previous example.

```elm
type alias Msg =
    { event : DragEvent
    , cursor : Coords
    , handlers : List ( Id, Rect )
    }

type DragEvent
    = Start
    | Move
    | Stop
```

We can now calculate the rectangle closest to the cursor when the user clicks.

```elm
closestRect : Coords -> List ( id, Rect ) -> Maybe id
closestRect cursor handlers =
    handlers
        |> List.map (Tuple.mapSecond (distance cursor << center))
        -- Find the vertex closest to the cursor.
        |> List.sortBy Tuple.second
        |> List.head
        |> Maybe.map Tuple.first

center : Rect -> Coords
center =
    Debug.todo "Implementation omitted for brevity"

distance : Coords -> Coords -> Float
distance =
    Debug.todo "Implementation omitted for brevity"
```

Once we have found the vertex the user picked up we just have to move it to the cursor on every `Move` event. The resulting `update` function looks like this.

```elm
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
```

And with that the we've completed the hard work for this particular example. You don't have to take my word for it! You can find the complete source code for this example [here][].

## Last example: an outline editor

Our final example is an outline editor. An outline is a tool for organizing our thoughts on a subject, but creating a list of concepts related to the thought, each of which have their own related thoughts, and so forth. The following image shows an example outline, which can be re-arranged using drag & drop.

![Rearranging outline nodes using drag & drop][outline.gif]

For this example we'll skip functionality for creating and deleting nodes to keep our focus on drag & drop behavior.

We'll start by creating a model for our outline editor. It will need to keep track of two things: the outline itself and, optionally, which node we're dragging.

```elm
type alias Model =
    { outline : List OutlineNode
    , draggedNode : Maybe DraggedNode
    }

type alias DraggedNode =
    -- For simplicity sake we're going to use the node's contents as an id.
    -- We get away with that here because we can ensure the nodes are unique:
    -- the user will not be able to edit them in this example.
    { node : String
    , cursorOnScreen : Coords
    , cursorOnDraggable : Coords
    }

type alias OutlineNode =
    Tree String

type Tree a
    = Tree
        { node : a
        , children : List (Tree a)
        }
```

Now we'll need to write behavior for the drag start, move, and end events.

The drag starts when the user pressed down on a node. We can put an `onClick` handler on each node to detect when this happens. We'll skip the implementation in this post, but it's part of the full source code if you're interested!

Then, as the user drags a node around we need to update that node's location in the outline. This part we're going to look at in detail.

Lastly the drag stop event. We already changed the outline while the user was moving the cursor, and so all that's left to do is change the model to its non-dragging state by setting `draggedNode` to `Nothing`.

### Moving nodes in an outline

And so our hardest task is figuring out where to put our dragged node when the user moves the cursor. What might the user intent when dragging the cursor to a certain location? To move the dragged node in front of another node, behind it, or nested beneath it?

We could draw invisible boxes in those positions that activate when the user moves over them, but the experience is unlikely to be great. Make the boxes too small and the user will not spend a lot of time over them, making the interface unresponsive for most of the time. Make the boxes too big though and they start to overlap, causing the upper box instead of the closest one that will receive the dragged node.

Lets again forget about dropzones and think about the behavior we want. As the user moves, we'd like to display the candidate node in the legal location closest to the cursor position. To be able to figure out which legal location is closest, we need to know where the legal locations are. To do this we are going to put invisible elements in the DOM at each location where we can move a node. In contrary to dropzones though, we're not going to bother giving these elements any special dimensions or positioning. We want them to just flow with the content on the page, and tell us their location when there's a drag going on.

We'll need a type describing the candidate outline positions that exist. We just enumerated the possibilities: we can plae a node before, after, or under another node.

```elm
type CandidatePosition
    = Before Text
    | After Text
    | Under Text
```

We'll create a JSON encoder for this type so we can tag each beacon element with its position in the outline. When we receive a drag event the positions are fed back to us:

```elm
type alias Msg =
    { event : DragEvent
    , cursor : Coords
    , beacons : List ( CandidatePosition, Rect )
    }
```

Remember the `closestRect` function from the polygon example? It's exactly what we need to find the `CandidatePosition` closest to the cursor! Once we have that, all we need is a function to that moves a node to its new position in an outline:

```elm
moveNodeInOutline : String -> CandidatePosition -> List OutlineNode -> List OutlineNode
```

It's a tricky function to write, but it doesn't have much to do with drag & drop and so I'm going to skip the implementation here. I include a solution with the full source code of this example. If you're interested in some thoughts on how to approach data transformations like these, check out this earlier blog post which includes a worked out example of a similar tree manipulation problem.

## Conclusion

When we need to perform a complicated task, its natural to start by looking for a library to do the heavy lifting for us. Unfortunately I've not found this approach fruitful in building drag & drop interfaces. I believe this is because the draggables and dropzones that are central to the libraries I've tried were not a great fit for the experiences I tried to build, of which I gave three examples in this post.

I've showed a different approach to building drag & drop UI's. This approach uses 'beacons', elements we mark because we'd like to know their position in the DOM for every drag event. I hope I have convinced you that using these we can build great drag & drop experiences without the corner cases.

[slider.gif]: ./imgs/slider.gif
[polygon.gif]: ./imgs/polygon.gif
[outline.gif]: ./imgs/outline.gif
