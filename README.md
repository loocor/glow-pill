# GlowPill (Swift)

A Swift / SwiftUI + Metal port of the
[Glow Pill](https://www.movements.dev/glow-pill) component from
[movements.dev](https://www.movements.dev): a black glass stadium with light
pooled along its bottom edge. It types through a list of phrases, and each
swap sends a surge of color up the glass.

## Upstream and attribution

This package is a re-implementation of the visual math of the original
WebGL component, ported line-for-line into Metal:

- **Upstream component**: Glow Pill — `@movements/react-glow-pill`,
  distributed through [movements.dev](https://www.movements.dev) by Nick
  ([nick.qa](https://nick.qa), GitHub: [@iduuck](https://github.com/iduuck)).
  The component page describes the design: "A black glass stadium with light
  pooled along its bottom edge. It types through your phrases, and each swap
  sends a surge of color up the glass."
- **Borrowed idea, credited upstream**: the cluster of nine lights along the
  bottom edge follows the line-beam approach of Border Beam (MIT, Jakub
  Antalik), as credited in the original shader and retained in our comments.
- **License status of the upstream**: at the time of publishing, the Glow
  Pill source is only distributed inside the movements.dev site bundle and no
  license statement was found for it. The related `@movements/react-glass`
  package on npm is MIT. If you are the upstream author and want this port
  handled differently, please open an issue.

## Extensions over the original

- **Swift/Metal port**: the whole visual pass runs as a single SwiftUI
  `layerEffect` shader (iOS 17+ / macOS 14+); the typewriter schedule, surge
  envelope, palette direction interpolation, and rainbow cursor are pure
  SwiftUI.
- **Light curtain switch** (`lights`): turns the whole liquid-light layer off,
  leaving a plain glass stadium with the typewriter.
- **Decoupled geometry** (`width` / `height`): the original fixes a 2.92:1
  aspect; here height is independent, and the shader derives the stadium SDF
  from the actual bounds.
- **Curtain thickness** (`thickness`): scales the bottom light pool height,
  the white core falloff, and the horizon dome radius independently of the
  stadium geometry.
- **Contained bottom light**: the rim's glow contribution is masked to the
  inner side of the glass so the bright pool reads as contained glass instead
  of a halo bleeding past the bottom edge.
- **Studio example**: an interactive macOS demo (`GlowPillStudio`) exposing
  every option: phrases, palette presets plus per-color pickers, background
  color, light-curtain/still/loop/paused toggles, glow, surge, liquid speed,
  per-char, hold, geometry, and replay.

## Usage

Add the package:

```swift
.package(url: "https://github.com/loocor/glow-pill.git", from: "0.1.0")
```

```swift
import SwiftUI
import GlowPill

GlowPill(width: 320)

GlowPill(
    phrases: ["Now live.", "Faster.", "Quieter."],
    width: 200,
    palette: .ember)
```

Options: `phrases`, `width` and `height` (height defaults to the 2.92:1
stadium aspect; pass `height` to decouple it), `timing` (`startDelay` /
`typeSpeed` / `hold`), `glow` (0–2), `surge` (0–1.5), `speed` (liquid speed
multiplier), `still` (freeze the liquid), `loop`, `paused`, `lights` (the
liquid-light curtain on/off), `thickness` (light-curtain thickness scale,
1 = reference), and `palette` (`warm` / `core` / `teal` / `cool` colors;
presets `.reference`, `.ember`, `.ice`).

The compiled Metal library is loaded from the package bundle
(`ShaderLibrary.bundle(.module)`), so no extra setup is needed when the
package is consumed from an Xcode project.

## Studio demo

```sh
# Open the package in Xcode, pick the GlowPillStudio scheme, and run.
open Package.swift
```

## Verification

`GlowPillTests` asserts that the compiled `default.metallib` is present in
the package bundle. Visual behavior was verified with the Studio demo:
static pool, typewriter with cursor, mid-surge refraction, lights-off plain
glass, contained bottom-edge light, light and dark backgrounds, and
non-default geometry. The original's compact `GlowButton` variant (button
bloom outside the glass, hover/press surge triggers) is not ported.

## License

MIT — see [LICENSE](LICENSE).
