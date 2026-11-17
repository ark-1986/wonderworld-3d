# WonderWorld 3D — offline game and optional team rooms

## Offline (no internet)
Open [WonderWorld_Team_3D.html](WonderWorld_Team_3D.html) directly in a modern browser. Android Chrome needs WebGL support. Use Play Offline. Shop items and coins are stored in this browser's localStorage.

## Multiplayer with friends on same Wi-Fi
Install free Node.js LTS on one Windows computer. Double-click START_LOCAL_WINDOWS.bat from this folder (or run `node room-server.js`). Find the computer's LAN IP using `ipconfig`; e.g. 192.168.1.7. All phones on the same Wi-Fi can open http://192.168.1.7:8765 and enter the server address `ws://192.168.1.7:8765`. One player creates a room, others join using the same eight-character code. Max eight players per room. Friendly fixed names and teams, no chat.

## Optional internet rooms
The repository-root [render.yaml](../render.yaml) configures a free Render Node web service with `rootDir: web`. Connect this GitHub repo at https://dashboard.render.com/ -> New -> Blueprint or New Web Service, select a free service, and deploy. The host returns a real address such as https://<assigned>.onrender.com. Open that address in a browser; in Team server use `wss://<assigned>.onrender.com`. No public server has been deployed by the code itself. Free hosts may sleep and reset rooms after inactivity; check quotas/terms. A public URL is only available after deployment.

## Features and limits
Third-person WebGL town with animated blocky avatar, touch joystick/camera, houses, slides, swing, foam-tag, obstacles, offline store with 64 virtual items (Hats/Shirts/Pants/Trails), buy/equip/unequip, autosaving and instant wardrobe. Multiplayer synchronizes avatar movement, cosmetics and house doors using private rooms. Online purchases remain local per-device, not authoritative and not synchronized as a common economy.

HTML includes Three.js source inline under MIT license; see THREE-LICENSE.txt. Offline uses no CDN, network requests or external models. There are no real-money transactions, Robux, advertising, open chat, user-uploaded assets or logins. This beta is not an authenticated or moderated public service and is not ready for unsupervised public release. Automated tests ran with a WebGL renderer stub due container GPU limits; mobile hardware performance and touch usability remain unverified.
