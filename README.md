# Tag 2.5

A local multiplayer tag game with physics, built in [Odin](https://odin-lang.org/) with [Raylib](https://www.raylib.com/) and [Clay](https://github.com/nicbarker/clay).

One player is it, marked with an arrow on their head, and if any other player contacts them, they become the tagged player. as of right now,
only one player can be tagged at a time. Once the timer ends, the player who is it will lose.

## Controls

| Player | Move | Jump |
|--------|------|------|
| 1 (blue) | A/D | W |
| 2 (red) | Left/Right arrows | Up arrow |

## Building

Requires the [Odin compiler](https://odin-lang.org/) with vendor libraries installed.

```sh
just build    # build only
just          # build and run
just gdb      # build and run under gdb
```

Or manually:

```sh
mkdir -p build
odin build src -debug -out:build/main
./build/main
```

## Making Maps

Maps are defined by a directory under `assets/arenas/<name>/` containing:

- **`<name>.txt`**: arena config, see format below
- **`pretty.json`**:  a Tiled `.tmx` exported as JSON, must use the "Embed in Map" option when adding the tileset to Tiled, otherwise the parser will fail
- **`*.png`**: tileset image, parallax background layers, and a thumbnail

### Arena config format

```
name: grass
layer: bg3.png 0.6
layer: bg2.png 1
layer: bg.png 1.2
tilemap: pretty.json
player: 300 400
player: 400 350
thumb: maynard.png
```

| Key | Purpose |
|-----|---------|
| `name` | Display name shown on the map select screen |
| `layer` | A parallax background image and its scroll factor (lower = slower, i.e. farther away) |
| `tilemap` | Path to the Tiled JSON export |
| `player` | Spawn position as `x y` (pixel coordinates); one `player` line per player |
| `thumb` | Thumbnail image shown in the map select screen |

### Tileset collision

Add a custom property (any name, type list of floats) to each tile in your Tiled tileset. The floats define a polyline as `(x0, y0, x1, y1, ...)` in normalized tile coordinates where `(0,0)` is top-left and `(1,1)` is bottom-right. Segments are drawn between consecutive points to form collision geometry.

Recommended tile size is 16×16, matching `PLAYER_RAD`.

## Tech

- **Odin** — the language and build system
- **Raylib** — windowing, rendering, input, texture loading
- **Clay** — retained-mode UI (menus, HUD, map select) with a Raylib renderer
- **Tiled** — map editor; the JSON parser reads embedded tilesets and per-tile collision data directly

## Acknowledgements

Thanks to [Nic Barker](https://github.com/nicbarker) for [Clay](https://github.com/nicbarker/clay), it made the UI layer a pleasure to build

## License

Public domain ([Unlicense](https://unlicense.org)).
