# Tag 2.5

## building

to build and run, just run the supplied just script, which leverages odins fast
and simple build pipeline. ensure the odin compiler is installed and your vendor
library's have been properly setup

## Improvements over the commercial tags

unlike the commercial tag tag 2.5 is completley opensource and free.
it is also easy to create your own maps and tilesets in tag 2.5 becuase so much
stuff is generated from json instead of being hardcoded, infact, our tag is so
much lighter that the binary is only a few mb and the codebase has a light
650 lines of code, as of when this was written. this is becuase instead of a
huge untiy runtime binary being shipped along with tag 1 and 2, tag 2.5 was written
entirely in odin, whihc lets it run almost as fast a C.

## Making maps

in order to make maps, you need a few things. the Tiled map editor, your pixle art
designer of choice and the odin compiler and a copy of its vendor library. if you
are on windows you might also need the msvc for linking. the compiler is needed
becuase there is currently no way to switch on what arena you want to play, so
you need to change some hardcoded values.

it is recomened that you keep the tiles small, recomened 16x16 becuase thats
what the player size is built off. after you have made a tileset, you can import
it into Tiled. its very important that you check the embed in map button when adding
the tileset becuase our json parser wont be able to open a .tsx or .tmx that contains
the tileset data. to add collision to your tiles, edit the embedded set and add
a custom property to each tile you want to have collision. it doesnt matter its
name, but it must be a list of floats. it is recomened to not add any other custom
properties either.

to configure the collsion data, add pairs of floats to define points and our
tilemap parser and generator will draw segments between each point you have defined.
there MAY be some preformance issues with having too many segments is one areana
but i am yet to discover that limit. the points are based off offsets from the
top-left, with higher y values being lower down. this means that the top-left is
`(0,0)` top-right is `(1, 0)` bottom-left `(0, 1)` bottom-right `(1,1)`

once you have finished your map, export the whole thing into the static folder
as json and change this line in the `create_test_game` function of `game.odin`

```odin
return create_game("./static/pretty.json", player_configs[:]) // change me!
```

make sure that the path looks exactly like that, starting from `tag2p5/` instead
of the `src/` dir. i dont know why it is like this.
