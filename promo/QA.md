# App Store teaser QA

Portrait claw-machine teasers rendered from the real `ClawEngine` + `ClawPlayfield` under `-PromoTrailer`.

## Exports

| File | Size | Duration | FPS | Audio |
| --- | --- | --- | --- | --- |
| `promo/claw-math-app-store-teaser-886x1920.mp4` | 886×1920 | 22.37s | 30 | yes (music + SFX mux) |
| `promo/claw-math-app-store-teaser-1200x1600.mp4` | 1200×1600 | 22.00s | 30 | yes (music + SFX mux) |

Both are independently framed (iPhone 393×852 layout scaled to 886×1920; iPad 834×1112 pad metrics scaled to 1200×1600). Not a crop or stretch of each other.

## Sequence (both formats)

1. Starts above the glass: elephant lowers in with the real level-start entrance. `6 + 7 = ?`. **20 nuts** in the standard 5-4-5-4-2 brick mound; **13**, **5** and **9** are fully uncovered.
2. Headline capsule (same top style as the later copy): **Find the right answer**.
3. Full trolley travel to the right, then to the left, then back over 13.
4. Real grab / lift / carry / drop of **13** into the answer bin. Score 01.
5. After a brief hang as elephant, headline **Unlock new characters**. Character becomes octopus (reef habitat) and hangs, then grabs the wrong nut **9**.
6. Octopus carries 9 to the bin and drops it. Switch to **bear** (forest habitat) only as the bin spits 9 back. Real spit-back, then bear aims at 5.
7. Bear aims at **5** (`9 − 4 = ?`). Switch to **dog** at contact with 5. Dog drops the correct nut and returns.
8. Back at rest: switch to **elephant**. Pile collapses to a 3-nut pyramid (8 / 6 / 12) at the bottom centre.
9. Headline **Grab all the nuts in time to win**. Three sped-up real grab loops. Timer counts down. Every grab in the teaser (not only these three) drops as soon as the trolley is over the nut; leftover swing is left in.
10. Real production celebration salto into the bin at native speed.
11. App icon (`app_icon_clean`) rotates in ~0.5s after the body reaches the bin mouth.

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
- [x] Bear only as the bin spits 9 back
- [x] Dog at contact with 5; elephant as soon as the dog is back at rest
- [x] Collapse to 3-nut pyramid; three sped-up deliveries that drop as soon as the trolley is parked
- [x] Real win / salto as elephant at native production speed
- [x] Habitats follow the character: savanna, reef, forest, agility field, savanna
- [x] Real app icon, sharp, rotates in
- [x] Unlock sound once
- [x] MP4s decode (H.264 + audio, full duration)
- [x] Release configuration build succeeds without `-PromoTrailer`

## Notes / deviations

- Every grab in the teaser drops as soon as the trolley is over the nut. Leftover swing is left in. The last three loops are ticked at ~1.78× (last loop ~1.35×). The salto plays at 1×, the same production bin animation as gameplay.
- Habitat ambience (birds, leaves, flags, fish, water) runs at 0.34× only while `-PromoTrailer` is set. Production motion is unchanged.
- The icon starts ~0.5s after the salto reaches the bin mouth, instead of waiting out the rest of the celebration.
- On iPad the teaser omits the inner wooden window frame so the hanging character stays in front of the left cabinet post. Production gameplay still composites that rim in front of the pile.
- The in-cabinet question plaque stays visible behind the icon (it is part of the machine, not the HUD overlay).
- Trailer mode is launch-argument only (`-PromoTrailer`). Normal production gameplay does not install the scripted board.

## How to re-render

```
promo/render-teaser.sh
```

Defaults: booted `iPhone 17` and `iPad Pro 11-inch (M5)`. Override with `PROMO_PHONE_SIM` / `PROMO_PAD_SIM`.
