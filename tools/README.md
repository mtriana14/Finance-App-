# tools

## make_branding.py

Regenerates the app-identity artwork in `assets/branding/`. The mark is drawn
from geometry rather than traced, so it can be re-derived exactly — artwork
that only exists as a PNG somebody once exported is a liability.

Needs Pillow, in a venv kept outside the Flutter project:

```bash
python3 -m venv ../artvenv
../artvenv/bin/pip install Pillow
../artvenv/bin/python tools/make_branding.py assets/branding
```

Then regenerate the Android resources:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### Swapping palettes

The script writes two sets: the session's lime on near-black into
`assets/branding/`, and the app's own dark-theme green into
`assets/branding/alt/`. To make the alternate one active, copy the four PNGs
from `alt/` up one level, change `#08090B` to `#14171C` everywhere in the
`flutter_launcher_icons` and `flutter_native_splash` blocks of `pubspec.yaml`,
and re-run the two generators above.
