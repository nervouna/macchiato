# Icon

`App/AppIcon.icon` is an Icon Composer document that Xcode compiles into `Assets.car` and `AppIcon.icns`.

- **Idea**: one tile, two halves. The left half is the light wallpaper (cream, apricot, sky blue), the right half is the dark one (navy, ember). An S-curve divides them and a disc straddles the seam: warm on the light side, silver on the dark side.
- **Layers** (front to back): `disc`, then `light half` and `dark glow`. All are flat SVGs on a 1024 canvas with `glass` on, except the dark glow. The background fill is a navy gradient.
- **Appearances**: the dark appearance swaps the light half for `light_half_dark.svg` (dusk plum and ember) and deepens the fill. Clear and tinted renditions come from the system.
- **Render**: `"$(dirname "$(xcode-select -p)")/Applications/Icon Composer.app/Contents/Executables/ictool" App/AppIcon.icon --export-image --output-file out.png --platform macOS --rendition Default --width 1024 --height 1024 --scale 1`. Use `--rendition Dark` for the dark appearance.
