class_name Palette
## Shared colors and layout constants for the whole game.

# Neon accents (sRGB). Emissive materials multiply these by an energy > 1.
const CYAN := Color(0.0, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.17, 0.78)
const PURPLE := Color(0.58, 0.3, 1.0)
const VIOLET := Color(0.36, 0.16, 0.9)
const GOLD := Color(1.0, 0.76, 0.2)
const RED := Color(1.0, 0.16, 0.22)
const ORANGE := Color(1.0, 0.45, 0.12)
const GREEN := Color(0.25, 1.0, 0.55)
const WHITE := Color(1.0, 1.0, 1.0)

# Environment.
const SKY_ZENITH := Color(0.012, 0.01, 0.05)
const SKY_MID := Color(0.07, 0.025, 0.2)
const SKY_HORIZON := Color(0.55, 0.08, 0.42)
const FLOOR_BASE := Color(0.03, 0.012, 0.07)
const FOG := Color(0.2, 0.05, 0.3)
const METAL_DARK := Color(0.07, 0.07, 0.11)

# Blaster colors per hand.
const LEFT_HAND := CYAN
const RIGHT_HAND := MAGENTA

# The player's head is assumed to be here when the dome is laid out. The dome
# shifts vertically at the start of a run to match the real head height.
const HEAD_CENTER := Vector3(0.0, 1.6, 0.0)
