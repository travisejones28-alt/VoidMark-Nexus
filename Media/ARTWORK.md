# Navigation HUD artwork

Created with the built-in image-generation tool using the user-supplied purple HUD reference as a style reference. No screenshot background or baked-in numerical values are included. Runtime conversion preserves alpha and resizes to power-of-two dimensions.

- `RouteCompass.tga`: 256 x 256 RGBA; north-facing violet compass arrow.
- `RoutePanel.tga`: 1024 x 256 RGBA; empty ornamental two-tier frame.

## Compass prompt
Create a production game UI sprite on genuinely transparent background. Reference image is STYLE reference only. Output ONLY the central purple faceted compass-arrow emblem, no screenshot, no environment, no text, no panel. A sharp amethyst arrowhead with beveled silver-lavender edges attached to a dark circular compass medallion with luminous four-point violet star. IMPORTANT arrow must point STRAIGHT UP (north), with arrow tip at top and compass circular pivot exactly at the CENTER of the square canvas, so rotation around canvas center is correct. Compass center at 50% x,50% y. Keep entirety of emblem and restrained purple glow within center 85% of square, symmetrical side fins. Crisp high-quality fantasy RPG HUD artwork matching reference, violet glow, transparent outside. Save generated asset.

The generated medallion pivot was visually inspected at approximately (0.5, 0.606); the live texture uses that pivot when the client provides normalized rotation points.

## Frame prompt
Produce ONE production 2D game UI frame asset based on reference image bottom HUD. Genuinely transparent background. Output just a centered wide horizontal double-tier rounded capsule dark obsidian panel with delicate beveled metallic violet and silver edges, soft purple edge glow, small pointed side ornaments and a small central hanging amethyst diamond at the bottom. The top tier is a broad rounded pill, lower tier slightly inset rounded pill, separated by thin glowing horizontal line. Match reference elegant purple fantasy WoW HUD style. Aspect ratio of panel about 4:1, fit panel with safe transparent margins in landscape canvas. BOTH TIERS EMPTY: no letters, numbers, labels, symbols, buttons, icons, progress bars, or dividers inside. No arrow, no scenery. We will overlay live text, progress and buttons in code. Keep interior nearly black and opaque, outside alpha zero.
