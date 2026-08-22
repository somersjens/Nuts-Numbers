# App Store teaser QA

Portrait claw-machine teasers rendered from the real `ClawEngine` + `ClawPlayfield` under `-PromoTrailer`.

## Exports

| File | Size | Duration | FPS | Audio |
| --- | --- | --- | --- | --- |
| `promo/claw-math-app-store-teaser-886x1920.mp4` | 886×1920 | 22.27s | 30 | yes (music + SFX mux) |
| `promo/claw-math-app-store-teaser-1200x1600.mp4` | 1200×1600 | 21.90s | 30 | yes (music + SFX mux) |

Both are independently framed (iPhone 393×852 layout scaled to 886×1920; iPad 834×1112 pad metrics scaled to 1200×1600). Not a crop or stretch of each other.

## Sequence (both formats)

1. Starts above the glass: elephant lowers in with the real level-start entrance. `6 + 7 = ?`. **20 nuts** in the standard 5-4-5-4-2 brick mound; **13**, **5** and **9** are fully uncovered.
2. Headline capsule (same top style as the later copy): **Find the right answer**.
3. Full trolley travel to the right, then to the left, then back over 13.
4. Real grab / lift / carry / drop of **13** into the answer bin. Score 01.
5. Headline **Unlock new characters**. Character becomes octopus and hangs, then grabs the wrong nut **9**.
6. Octopus carries 9 to the bin. Switch to **bear** only while hanging over the bin still holding 9. Wrong drop, real spit-back.
7. Bear aims at **5** (`9 − 4 = ?`). Switch to **lion** at contact with 5. Lion drops the correct nut and returns.
8. Back at rest: switch to **elephant**. Pile collapses to a 3-nut pyramid (8 / 6 / 12) at the bottom centre.
9. Headline **Grab all the nuts in time to win**. Three sped-up real grab loops. Timer counts down.
10. Real celebration salto into the bin (release slightly faster than the speed section so the handoff stays smooth).
11. App icon (`app_icon_clean`) rotates into the centre over the settled playfield.

Unlock SFX (`sfx_character_unlock`) plays once, on the octopus change.

## Checks

- [x] iPhone 886×1920 portrait
- [x] iPad 1200×1600 portrait
- [x] Independently framed and inspected
- [x] Real cabinet, claw, nuts, bin, joystick, Pak! button
- [x] Elephant lowering at start (level-start entrance)
- [x] First copy **Find the right answer**, top capsule, not a bottom bubble
- [x] 20 nuts at start; 13 / 5 / 9 fully uncovered
- [x] Full move right and left
- [x] Correct 13 grabbed and dropped
- [x] Unlock headline; octopus hang then wrong grab of 9
- [x] Bear only once octopus is hanging over the bin with 9
- [x] Lion at contact with 5; elephant only after returning to rest
- [x] Collapse to 3-nut pyramid; three sped-up deliveries
- [x] Real win / salto as elephant; faster release after the rush
- [x] Real app icon, sharp, rotates in
- [x] Unlock sound once
- [x] MP4s decode (H.264 + audio, full duration)
- [x] Release configuration build succeeds without `-PromoTrailer`

## Notes / deviations

- The three fast deliveries are real grab loops, ticked at ~1.78× (last loop ~1.35×). After each drop the trolley parks on the next nut’s rest position (no analog hunt). The salto keeps a ~1.32× tick with a small extra boost from the release.
- iPhone and iPad durations differ by ~0.4s because pad geometry changes trolley travel and carry time.
- On iPad the teaser omits the inner wooden window frame so the hanging character stays in front of the left cabinet post. Production gameplay still composites that rim in front of the pile.
- The in-cabinet question plaque stays visible behind the icon (it is part of the machine, not the HUD overlay).
- Trailer mode is launch-argument only (`-PromoTrailer`). Normal production gameplay does not install the scripted board.

## How to re-render

```
promo/render-teaser.sh
```

Defaults: booted `iPhone 17` and `iPad Pro 11-inch (M5)`. Override with `PROMO_PHONE_SIM` / `PROMO_PAD_SIM`.
