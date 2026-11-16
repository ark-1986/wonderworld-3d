# WonderWorld 3D: Free APK aur Online Multiplayer Setup

**Ye source project hai, ready APK nahi.** Is waqt actual APK ya phone gameplay test complete nahi hua. Lekin game ka 3D world aur multiplayer server code package mein maujood hain.

## Sab se pehle game test karna (bilkul free)

**Sirf Android phone ho:**
1. Android par official [Godot 4.5.2 Android Editor](https://godotengine.org/download/archive/4.5.2-stable/) install karein. Android editor early access mein hai.
2. WonderWorld3D ZIP download kar ke unzip karein.
3. Godot Editor mein `godot/project.godot` import karein. Start ke liye **PRACTICE OFFLINE** select karein.
4. Editor mein koi script error show ho to screenshot share karein; abhi project phone par run karke verify nahi ho saka.
5. Godot ke Project > Export mein Android preset aur debug APK export ka option use karein. Android editor khud Android APK export kar sakta hai; agar issue aaye to PC / GitHub Actions wali method use karein.

**Laptop/PC ho:**
1. Windows/Linux/macOS par Godot 4.5.2 download karein.
2. `godot/project.godot` open karke game run karein.
3. Android APK build karne ke liye README mein OpenJDK/SDK/export steps follow karein.
4. APK ka alternative: `.github/workflows/android-debug-apk.yml` ko GitHub repo mein upload kar ke GitHub Actions ke through APK artifact generate karein. Ye workflow abhi practically run nahi hui.

## Live same world multiplayer (bilkul free starter)

1. Free Cloudflare account banayein.
2. PC par Node.js install karein.
3. Package ke `server` folder mein terminal open karein:

   ```
   npm install
   npx wrangler login
   npx wrangler deploy
   ```

4. Cloudflare Worker ka `https://...workers.dev` link milay ga.
5. `godot/scripts/network.gd` mein is line ko replace karein:
   `const SERVER_URL: String = "wss://REPLACE-WITH-YOUR-WORKER.workers.dev"`
6. APK export karein, 2 phones par install karein.
7. Phone #1: CREATE PRIVATE ROOM. Phone #2: SAME CODE type karke JOIN. Ab dono real-time ek hi room mein honge, agar network deployed aur tests pass hon.

**Limit:** Room mein max 8 players. Koi public chat nahi. Free plan par 24/7 unlimited traffic possible nahi.

## Files
- `godot/` = asli 3D game source (browser page nahi).
- `server/` = live multiplayer server.
- `.github/workflows/` = free hosted Android APK build workflow.
- `TEST_CHECKLIST.md` = testing checklist.
