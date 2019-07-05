# Drag & Drop without Draggables & Dropzones

Why is building drag & drop UIs so hard? They've have been around for a while, so you would be forgiven for thinking they're a solved problem. Certainly there's high quality libraries to help us build drag & drop UIs, and these days we even have an official HTML5 drag & drop API! What's going on here?

I've come to the conclusion a big part of the problem is our choice of tools: the draggables and dropzones most libraries provide for building drag & drop interactions. Not using draggables and dropzones to build UIs often simplifies their construction massively.

That's a pretty sweeping statement for a broad term like 'drag & drop', so I'd better back it up! To do so I'll show you three examples of drag & drop UIs built without draggables or dropzones. These examples come from real projects, but I've stripped them down to their drag & drop essentials for this post. I'll include what I believe to be the most relevant code snippets in those post, and invite you to look at [the full source code] if you'd like to learn more!

Before we start with those examples, lets start with a quick refresher on draggables and dropzones.

## A Refresher on Draggables & Dropzones

To learn what draggables and dropzones are lets look at [Trello], an application where they are easy to identify. In Trello you can drag cards between lists. This makes cards draggables and lists dropzones.

![A screenshot of the Trello app, showing some lists and cards][trello.png]

On closer inspection though things aren't as clear cut. For example, when you drop a card next to a dropzone you might expect that card to return to its original list, or even get lost. But what happens is that the card will land in the list nearest to where we dropped it. That's much nicer for the user, but it's not clear how we might achieve it using draggables and dropzones.

## Our first example, A Timeslot Selector

Our first example is a UI for selecting a time slot in a day. This UI represents a day as a horizontal bar, in which you can select a slot using drag & drop.

![Selecting a time slot by drag & drop][slider.gif]

I'd like to start these examples by imagining what a draggables and dropzones implementation might look like. In this example it's unclear what our draggables and dropzones even are. We could make the time slider the draggable, because clicking anywhere in it should start the drag operation even if we don't drag the time slider itself. The screen as a whole might serve as a dropzone, because the user should be able to release the cursor anywhere to finish the drag. Already this approach feels pretty hacky, and we haven't even written any code yet!

Lets start again from scratch without assuming draggables or dropzones this time and see where it takes us. We'll begin in a way we often begin an Elm application: by designing our Model. Our application needs to store a time slot which is nothing more than a start and end hour.

```elm
-- In this example a time slot always covers whole hours,
-- but we could make this minutes or seconds if we wanted.
type alias Model =
    { from : Hour, until : Hour }

type alias Hour =
    Int
```

Now for the drag & drop behavior. In our example all you can do is drag left-to-right. This means that when the user presses down we store the hour the cursor is over as the left bound of the time slot. Then as the cursor moves to the right we will update the `until` time of the timeslot, until the user releases.

We will need to know which hour the cursor is over. We can calculate this if we know the position of the cursor and the position and dimensions of the slider on the screen. Lets be optimistic and assume we just get that information. Our `Msg` type we design like this:

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

Now we can proof we are able to calculate the hour the cursor is over if we get `Msg`s that look like the above.

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
        -- Ensure we get a number between 0 and 23,
        -- even if the cursor moves to the left or right of the slider.
        |> atMost 23
        |> atLeast 0
```

All that's left to do is use this in our `update` function. When we get a `Start` event we update the `from` field in the model, and when we get a `MoveOrStop` event the `until` field.

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

And we have an app! Well almost, we've not discussed where these `Msg`s will be coming from. There's a bit of JavaScript responsible for that, which I'll talk more about in a bit. If you want to peak ahead check out the [time slider source code].

## Second example, a polygon editor

Our second example is a tool for editing polygons. We want users to be able to pick up a vertex of a polygon and move it somewhere else.

![Dragging a vertex of a polygon][polygon.gif]

You see those vertices? Those sure look like draggables! But these vertices are small and easy to miss, so we'd want our draggables to be bigger. We could achieve this by making the draggables invisible `div` elements centered on these vertices, but that gets us in trouble when the `div` elements are so close they overlap. At that point a click won't select the closest vertex but the top vertex.

We're going to leave those draggables in the toolbox and see how far we can get without them. As usual we start by defining a model to store the polygon we're editing.

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

The drag starts when the user presses down a vertex to select it. For this we'll need to calculate the vertex closest to the cursor, which we can do if we know the positions of the cursor and all vertices. Lets create a `Msg` type that contains those positions. We can reuse the `Coords` and `Rect` types from the previous example.

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

Perfect! Now we can calculate the rectangle closest to the cursor when the user clicks.

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

Once we have found the vertex the user picked up we have to move it to the cursor on every `Move` event. The resulting `update` function looks like this.

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

And that's that! Again I skipped over the JavaScript that produces our messages and I promise we'll get to that in a moment. The full [polygon editor source code] is available if you're interested!

## Last example: an outline editor

Our final example is an outline editor. An outline is a tool for organizing our thoughts on a subject, but creating a list of concepts related to the thought, each of which have their own related thoughts, and so forth. The following image shows an example outline which can be re-arranged using drag & drop. We'll keep our scope small again by not bothering with creating and deleting nodes.

![Rearranging outline nodes using drag & drop][outline.gif]

We'll start by creating a model for our outline editor. It will need to keep track of two things: the outline itself and which node we're dragging.

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

The drag starts when the user pressed down on a node. We can put an `onClick` handler on each node to detect when this happens. We'll skip the implementation in this post, but it's part of the full [outline editor source code] if you're interested!

Then, as the user drags a node around we need to update that node's location in the outline. This part we're going to look at in detail.

Lastly the drag stop event. We already changed the outline while the user was moving the cursor, and so all that's left to do here is change the model to its non-dragging state by setting `draggedNode` to `Nothing`.

### Moving nodes in an outline

Our hardest task is figuring out where to put our dragged node when the user moves the cursor. What might the user intent when dragging the cursor to a certain location? To move the dragged node in front of another node, behind it, or nested beneath it?

Using dropzones we could draw invisible boxes in those positions that activate when the user moves over them, but the experience is unlikely to be great. Make the boxes too small and the user will not spend a lot of time over them, making the interface unresponsive for most of the time. Make the boxes too big and they start to overlap, causing the upper box instead of the closest one that will receive the dragged node.

Lets forget about dropzones and think about the behavior we want. As the user moves, we'd like to display the candidate node in the location closest to the cursor position that might receive it. To be able to figure out which of those locations is closest we need to know where they are. To do this we are going to put invisible elements in the DOM at each location where we can insert the dragged node. Contrary to the dropzones approach we're not going to bother giving these elements any special dimensions or positioning. We want them to just flow with the content on the page, and keep us apprised of their location. These aren't dropzones but beacons.

Apart from their coordinates in the DOM, our beacons will also need to describe their location in the outline. A beacon can define its location in relative to another node in the outline.

```elm
type CandidatePosition
    = Before String
    | After String
    | PrependedIn String
    | AppendedIn String
```

We'll create a JSON encoder for this type so we can tag each beacon element with a data attribute containing its position in the outline. We'll then set up our JavaScript to find all elements with such a data attribute in the DOM and feed their coordinates back to us on each drag event. That will allow us to define a type for drag events containing the positions of our beacons on the screen.

```elm
type alias DragMsg =
    { cursor : Coords
    , beacons : List Beacon
    }


type alias Beacon =
    ( CandidatePosition, Rect )
```

Remember the `closestRect` function from the polygon example? It's what we need to find the `CandidatePosition` closest to the cursor! Once we know which candidate position is closest, all we need is a function to that moves a node to its new position in an outline:

```elm
moveNodeInOutline : String -> CandidatePosition -> List OutlineNode -> List OutlineNode
moveNodeInOutline = Debug.todo "See full source code for implementation!"
```

It's a tricky function to write, but it doesn't have much to do with drag & drop and so I'm skipping the implementation here. I include a solution with the [outline editor source code]. If you're interested in some thoughts on how to approach data transformations like these, check out this earlier [post on conversion functions], which includes an example of a similar tree manipulation problem.

## Necessary JavaScript

I promised I'd get back at the JavaScript required to make these examples work. All three examples use the same JavaScript code, because it turns out they have the same needs. In every example there's one or more Html elements on the page that we need to track the position and dimensions of as a drag interaction takes place. What our JavaScript code needs to do is generate events when the mouse gets pressed, moved, and released, and bundle with those events the positions of all elements we want to track. We identify those elements by giving them a data attribute with their 'beacon ID'.

There's tons of ways to write this code and I don't believe mine is particularly insightful, so I'll not reprint it here. The [draggable.js source code] for these examples is available though in case you're interested.

## Conclusion

When we need to perform a complicated task, its natural to start by looking for a library to do the heavy lifting for us. Unfortunately I've not found this approach fruitful in building drag & drop interfaces. I believe this is because the draggables and dropzones that are central to the libraries I've tried were not a great fit for the experiences I tried to build, of which I gave three examples in this post.

I've showed a different approach to building drag & drop UI's. This approach uses 'beacons', elements we mark because we'd like to know their position in the DOM for every drag event. I believe this approach allows us to create better drag & drop experiences with far fewer corner cases.

[slider.gif]: ./imgs/slider.gif
[polygon.gif]: ./imgs/polygon.gif
[outline.gif]: ./imgs/outline.gif
[trello.png]: ./imgs/trello.png
[trello]: https://trello.com/
[the full source code]: ./example-code
[time slider source code]: ./example-code/time-slot-example/src/Main.elm
[polygon editor source code]: ./example-code/polygon-example/src/Main.elm
[outline editor source code]: ./example-code/outliner-example/src/Main.elm
[draggable.js source code]: ./example-code/draggable.js
[post on conversion functions]: https://dev.to/jwoudenberg/conversion-functions-five-stars-2l87
