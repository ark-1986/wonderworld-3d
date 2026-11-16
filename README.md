# WonderWorld 3D — Android Multiplayer Starter (v0.1 source)

A **real native Godot game** prototype, NOT a browser wrapped in an APK.

What's included:
- Original stylized 3D world rendered with Godot meshes: island, bright houses, trees, flowers, jumping platforms, gems, sea and sunshine.
- Block-style animated characters, mobile touch joystick, jump button, third-person camera, offline practice and original synth background music.
- Safe preset nicknames, private eight-character room codes, up to eight WebSocket players, remote-player interpolation, room scoreboard, shared gems.
- Cloudflare Worker + SQLite-backed Durable Object room server for free-tier testing, and a GitHub Actions Android debug-APK workflow.

## Important status

This is a **source-code starter project**. The code and game assets have been assembled and checked for internal consistency, but an Android APK has **NOT** been compiled or tested on a phone in the creation environment (the Godot engine and Android SDK were not available). **Multiplayer will not work until you deploy the server and paste its URL into `godot/scripts/network.gd`.** It is not ready for public distribution to children without proper testing, a privacy/safety review, and improved anti-cheat/abuse protection.

## The simplest way to try it (free)

### A. Open game in Godot (Windows, Linux, macOS)
1. Install the free Godot Engine **4.5.2 standard edition**, from https://godotengine.org/download/archive/4.5.2-stable/.
2. Unzip this package. Open `godot/project.godot` in Godot.
3. Press F6/F5, choose **PRACTICE OFFLINE**, use WASD/arrows and Space on a computer. Android controls are shown on screen.
4. If an error appears, check Godot's Debugger > Errors; this release has not been runtime tested yet.

### B. Get real-time online play (Cloudflare Free plan)
1. Create a free Cloudflare account at https://dash.cloudflare.com/.
2. Install Node.js LTS free: https://nodejs.org/ (if using a computer).
3. In a terminal run:
   ```sh
   cd server
   npm install
   npx wrangler login
   npm run deploy
   ```
4. Copy the resulting URL, normally `https://wonderworld-rooms.<your-subdomain>.workers.dev`.
5. Test the URL in a browser by adding `/health` (it should return JSON with `ok: true`).
6. In `godot/scripts/network.gd`, set `SERVER_URL` to `wss://wonderworld-rooms.<your-subdomain>.workers.dev`.
7. Run the game on two phones or two computers. On device A select **CREATE PRIVATE ROOM** and share its code with device B. On device B enter the same code and tap **JOIN**. Both should be in the same room; test live movement and gem pickup.

Cloudflare Durable Objects with SQLite storage currently offer a Free plan; the plan has usage caps, so it is for limited testing, **not unlimited commercial multiplayer**. Check https://developers.cloudflare.com/durable-objects/platform/pricing/.

### C. Build a native Android APK (free)
**Option 1: your computer**
1. Install Godot 4.5.2, OpenJDK 17, and the Android SDK as described at https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html.
2. In Godot, set Editor Settings > Export > Android > Java SDK Path and Android SDK Path.
3. Install the **4.5.2** export templates via Editor > Manage Export Templates.
4. Project > Export > Android. Confirm the **INTERNET** permission is checked. Choose **Export Project** with debug mode enabled to build an APK.
5. Install that APK on an Android phone, accepting the appropriate local sideload prompt. Use only on your own test devices.

**Option 2: GitHub Actions, no local Android SDK**
1. Create a **private** GitHub repository and upload this whole project's *contents* to its root (including `.github/workflows/android-debug-apk.yml`).
2. In your repo open Actions > Build WonderWorld 3D Android APK > Run workflow.
3. Once the workflow completes, open its run and download the `WonderWorld3D-Android-debug-APK` artifact; unzip to find the APK. This workflow has not yet run; small environment-specific adjustments may be needed.
4. GitHub has free Actions minutes for eligible repositories/plans, subject to usage limits.

You can alternatively install the official Godot 4.5.2 **Android editor**, unzip this project on your phone, import `godot/project.godot`, test offline, and use Project > Export to create an APK directly on Android without a separate local JDK/SDK. The Android editor is early access and may be awkward on small screens. See https://docs.godotengine.org/en/4.5/tutorials/editor/using_the_android_editor.html.

## What's deliberately not included yet
- Accounts, personal info, open/public chat, social feeds, purchases, ads, analytics, GPS or in-app billing.
- Persistent cloud character progress (room scores reset when a new room starts).
- Advanced 3D terrain, professionally modeled character art, full animation rigs, matchmaking, parental consent, moderation dashboard, or production-ready anti-cheat.

## Game controls
| Device | Move | Jump | Room |
|---|---|---|---|
| Android | lower-left joystick | lower-right JUMP | top of screen |
| Desktop | WASD or arrow keys | Space | top of screen |

## File map
```text
godot/
  project.godot               Native Godot project
  scenes/main.tscn            Main scene
  scripts/game.gd             World, UI, coins, scoring, room setup
  scripts/avatar.gd           Player 3D geometry + physics
  scripts/network.gd          WebSocket client; SET SERVER_URL HERE
  scripts/virtual_joystick.gd Touch control
  assets/                     Original icon, sounds and music
  export_presets.cfg          Android preset, including INTERNET
server/
  src/index.ts                Worker + multiplayer Durable Object
  wrangler.jsonc              Free SQLite-backed Durable Object
  package.json                Developer dependencies/scripts
.github/workflows/
  android-debug-apk.yml       CI build (after upload to GitHub)
```

## Privacy and kid safety
Private room codes are unlisted but do not constitute authentication. The server rejects free-text chat and only allows preset nicknames; no personally identifiable details are asked for. The prototype currently uses a shared client-authoritative world with basic movement/coin checks, which is **not** strong enough to prevent all cheating or unwanted access. For public launch, add proper room ownership/locks, parental controls, abuse reporting, child privacy compliance (COPPA and applicable laws), data retention rules and performance testing.

---
License: Project source and original generated assets may be modified and reused by the recipient; Godot's engine remains under its own open-source license. No Roblox trademarks or protected assets are copied.
