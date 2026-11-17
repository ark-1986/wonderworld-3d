# Visual direction: WonderWorld Adventure City

## Target

A delightful, high-color 3D children's adventure town: saturated green ground, clear turquoise sky, landmark red-roof castle, shops with recognizable silhouettes, walking characters, carnival decorations, cozy flowerbeds and playful activity districts. Focus on *game readability and stable mobile frame rate* instead of photorealism.

## V0.3 implemented

- Eleven single-mesh GLB hero props built with original procedural geometry. Approx. 0.55 MB total uncompressed GLB files, with baked per-vertex colors.
- Placed in five playable areas plus Central Plaza; props include real 3D geometry and optional blocking colliders for large objects.
- Existing procedural city, six original seamless tiling PNG textures, dynamic daylight and basic third-person 3D shadows.
- Improved avatar color accents, quick-travel button and a lighter offline HUD.

## Difference from reference illustration

The reference was aspirational generated artwork, not a real game render. V0.3 remains a stylized indie prototype with simple character rigs, not the same detailed animated cast, game cinematography or density in the reference. The next visual milestone should prioritize: (1) higher-detail avatar animations, (2) character outfit customization, (3) curated CC0 city/nature meshes, (4) asset-specific shading, (5) interactive shop/quest NPCs, (6) mobile device performance QA and (7) lighting tuned from actual device screenshots.

## Mobile performance goals, **not yet measured**

- Target 30 FPS on mainstream Android phones; 60 FPS optional on higher-end devices.
- Target 1–8 test players per private room within free quotas, with actual latency/load testing before any player-capacity claim.
- Profile draw calls, triangle count, render resolution, UI clipping, touch controls, heat and battery usage on representative ARM64 devices.
