# Tag 2.5

## Building

To build and run, just run the supplied just script, which leverages Odin's fast
and simple build pipeline. Ensure the Odin compiler is installed and your vendor
libraries have been properly set up.

## Improvements over the commercial tags

Unlike the commercial Tag, Tag 2.5 is completely open source and free.
It is also easy to create your own maps and tilesets in Tag 2.5 because so much
stuff is generated from JSON instead of being hardcoded. In fact, our Tag is so
much lighter that the binary is only a few MB and the codebase has a light
650 lines of code, as of when this was written. This is because instead of a
huge Unity runtime binary being shipped along with Tag 1 and 2, Tag 2.5 was written
entirely in Odin, which lets it run almost as fast as C.

## Making maps

In order to make maps, you need a few things: the Tiled map editor, your pixel art
designer of choice, the Odin compiler and a copy of its vendor library. If you
are on Windows, you might also need MSVC for linking. The compiler is needed
because there is currently no way to switch on what arena you want to play, so
you need to change some hardcoded values.

It is recommended that you keep the tiles small, recommended 16x16, because that's
what the player size is built off. After you have made a tileset, you can import
it into Tiled. It's very important that you check the embed in map button when adding
the tileset because our JSON parser won't be able to open a .tsx or .tmx that contains
the tileset data. To add collision to your tiles, edit the embedded set and add
a custom property to each tile you want to have collision. It doesn't matter its
name, but it must be a list of floats. It is recommended to not add any other custom
properties either.

To configure the collision data, add pairs of floats to define points, and our
tilemap parser and generator will draw segments between each point you have defined.
There MAY be some performance issues with having too many segments in one arena,
but I am yet to discover that limit. The points are based off offsets from the
top-left, with higher y values being lower down. This means that the top-left is
`(0,0)`, top-right is `(1, 0)`, bottom-left `(0, 1)`, bottom-right `(1,1)`.

Once you have finished your map, export the whole thing into the static folder
as JSON and change this line in the `create_test_game` function of `game.odin`:

```odin
return create_game(STATIC_DIR + "pretty.json", player_configs[:])
```

If your JSON is even slightly wrong, it can lead to severe memory bugs and
panics.
