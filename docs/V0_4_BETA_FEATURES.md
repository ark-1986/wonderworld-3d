# WonderWorld 3D – Interactive World v0.4.0 beta

## What is playable
- **Wonder Store:** 84 original virtual cosmetic styles across hats, wings, backpacks, auras, pet collars, vehicle wraps and toys. Purchase and equip with in-game exploration points earned offline. No real-money payments, ads or accounts.
- **Homes:** three new hollow, furnished family homes north of the plaza. Walk up to a door, press the contextual action and enter. Roof hides when the local player steps inside.
- **Water slide:** tap the contextual action in the splash district to ride an animated downward path, with a completion reward and cooldown; no instant-teleport substitute.
- **Swing playground:** two interactable swings in the pet district, with damped gravity-driven pendulum motion. Ride or exit.
- **Foam-tag practice:** opt-in timed target challenge in the eastern play zone, with colorful moving targets, soft foam projectiles and points. There is no violence, health damage or PvP.
- **Store kiosk:** 3D Wonder Store stand near the town plaza; interact or use the SHOP HUD button.

## Installation / signing
This beta uses Android package **org.wonderworld.adventurecity.beta4** to install alongside the earlier **org.wonderworld.adventurecity** v0.3.1 game. Progress is stored separately. This is a debug APK with temporary CI signing, not a production update channel. A stable private signing key must be configured before distributing incremental updates.

## Limitations
- Multiplayer movement uses the existing Cloudflare Worker room protocol and will only work after owner deploys/configures the server URL. New store, slide, swing and foam-tag gameplay are currently **offline-only**; house doors are local and not network synchronized.
- Item catalog is 84 original visual variations, **not unlimited content**. Future creators, moderation, upload tools, catalog search, trade, purchases and servers are separate major projects.
- These are stylized/procedural mobile graphics. Professional Roblox-scale polished games need more original character animation, models, sound design, menus, safety review, and device performance optimization.
- Purchases use earned virtual points only. No Robux, real payments, external marketplace, ads, chat or tracking.
- Account/cloud sync, multi-device saving, server moderation, age controls and user-generated content are **not implemented**.
- A successful GitHub build and headless gameplay test are necessary but do **not** replace manual Android device testing.

## Test and build
CI runs tools/validate_release.py, server/test/protocol.mjs, the native scene smoke test, plus:
`godot --headless --path godot --script res://tests/feature_smoke.gd`
which tests store purchase/equip, house doors/interiors, animated slide, swing, and foam-tag.
Debug APK built by .github/workflows/android-debug-apk.yml.
