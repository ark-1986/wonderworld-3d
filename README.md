# WonderWorld 3D — Adventure City v0.3.1.1 | Professional art pass + multiplayer travel reliability

**Native Android 3D game source; build and device testing pending.** This is the next development iteration of WonderWorld Adventure City. It is not a Roblox-scale platform, and the illustrated reference image is not a screenshot of this game.

## What's changed from v0.2

- **11 original, colored low-poly 3D prop models** under `godot/assets/models/`: festival gate, candy kiosk, Ferris wheel, lantern, park bench, balloon cart, pet house, trophy portal, flower bed, magic tower and palm tree. They are real GLB meshes integrated into the live Godot scene and built as single-mesh props for lower draw-call overhead on mobile.
- **Denser city staging:** welcoming gate, castle turrets, water-park Ferris wheel, pet houses, race/obby portals, flowerbeds, palms, benches and lanterns across the five existing districts.
- **Brighter but controlled art direction:** physically lit materials, original color textures from v0.2 and optional 4× MSAA anti-aliasing. Unlike v0.1's nearly white ground, v0.2+ uses textured grass, cobblestone and warm cinema-like sunlight.
- **Better on-phone experience:** `EXPLORE ▶` travels between the six landmarks. Offline mode hides the unused Friends scoreboard and COPY button, preserving more view of the game world.
- **Avatar details:** facial highlights, jacket and shoe accents on the animated low-poly avatars.
- **Large-world multiplayer fix:** the original WebSocket server discarded any player position beyond 30m; it now supports the actual city footprint and server-approved fast-travel destinations, with cooldown and input validation.
- **No ads, chat, purchases, accounts or children's personal information** in the included source.

## Game areas

Central Plaza (spawn and fountain), Adventure Castle, Pet Garden, Splash Water Park, Racing Challenge, Rainbow Obby. Activities already in v0.2: collectible gems, zone discovery, pet companion, toy-car speed mode, five-checkpoint race, slide action and parkour.

## Build and play

1. Use **Godot 4.5.2 standard**. Import `godot/project.godot` and launch `PRACTICE OFFLINE` to test.
2. Android debug export: `.github/workflows/android-debug-apk.yml` contains a GitHub Actions build workflow using free Godot and Android CLI packages. On a suitable GitHub account, uploading all files with their **folder structure** to `main` triggers the build. Any errors need correction before a real APK exists.
3. `server/` contains a free-tier Cloudflare Worker + Durable Object room server (up to eight test players per room). Deployment requires a user-owned Cloudflare free account, then updating `SERVER_URL` in `godot/scripts/network.gd`. Without this, **offline practice works only**; selecting online rooms will show an explanation.
4. Android installation and gameplay must be checked on physical devices. V0.3 has **NOT yet been compiled or tested on a phone.** The last verified APK in the project history is the older v0.1 build and contains neither the city expansion nor these new models.

## Copyright, art, safety

The 11 GLBs are generated entirely with original scripts, no purchased or scraped game meshes. 6 original PNG textures and music/sounds came from the existing project. No branded Roblox models or trademarked designs are included. Kenney, KayKit and Quaternius offer optional free/CC0 packs; see `docs/FREE_ASSETS.md` for official links and license notes. **Optional packs are not bundled or presented as integrated.**

An APK building successfully is **not** proof that its graphics, performance or live multiplayer meet professional release standards. The game still needs in-engine visual QA, touch-device FPS tests, social-room tests, accessibility review and child-safety/legal review before public release.

See `docs/BUILD_CHECKLIST.md` and `docs/ART_DIRECTION.md`.

**Windows GitHub upload helper:** If you already have the public repository and Git for Windows installed, extract this ZIP and run `PUSH_TO_GITHUB_WINDOWS.bat`; it operates only on `ark-1986/wonderworld-3d`, merges game files, commits and pushes using your local GitHub sign-in. You do not need to upload 44 files one by one.

## v0.3.1 travel/CI refinement

See `docs/0.3.1_CHANGES.md` for server-approved travel acknowledgments, new room protocol tests, and headless game startup validation in GitHub Actions. This is still source-only until compiled and phone-tested.
