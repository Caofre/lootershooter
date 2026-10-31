# Zombie Shield (CoD Zombies buildable) for Garry's Mod

## Install
Drop the `zombie_shield` folder into `garrysmod/addons/` so you end up with
`garrysmod/addons/zombie_shield/lua/...`. Restart the game/server.

## How it plays
1. Spawn menu > Entities > **Zombie Shield**: three `Shield Part` entries (Door, Dolly, Clamp) and a `Shield Workbench`.
2. Press **E** on each part to collect it (the HUD tracks them).
3. Hold **E** on the workbench for `zs_shield_crafttime` seconds to build.
4. The shield is a physics prop strapped to your back. Hits from behind land on it, it loses durability,
   tints toward red as it wears down, and breaks (with debris) at 0.
5. Dying loses the shield and any collected parts.

## Test commands (admin)
`zs_giveparts`, `zs_giveshield`, `zs_removeshield`

## ConVars
| ConVar | Default | Meaning |
|---|---|---|
| `zs_shield_health` | 600 | damage the shield absorbs before breaking |
| `zs_shield_damagescale` | 1 | multiplier on damage dealt to the shield |
| `zs_shield_crafttime` | 3 | seconds to hold E at the workbench |
| `zs_shield_arc` | 70 | half-angle of the rear cone covered vs melee/blasts |
| `zs_shield_back` / `zs_shield_up` | 14 / 40 | mount offset from the player |
| `zs_shield_pitch` / `yaw` / `roll` | 90 / 0 / 0 | model rotation offset |

If the shield looks sideways/flat, adjust the pitch/yaw/roll convars live (or change `ZS.ShieldModel` in
`lua/autorun/zombie_shield.lua` and re-tune).

## How blocking works
- The shield is a real vphysics prop, driven to the back mount with shadow control every physics tick.
  Its collision group ignores players/world but is still hit by bullet and melee traces, so hits land on the prop itself.
- Safety nets for damage that bypasses the prop: a per-pellet check in `EntityFireBullets` (did the bullet pass through the
  shield box before reaching the player?) and a rear-cone check in `EntityTakeDamage` for melee/blasts/props.
- Damage types blocked: see `ZS.BlockMask` (bullets, slash, club, crush, blast).

## API
`ZS.GivePart(ply, id)`, `ZS.GiveShield(ply)`, `ZS.RemoveShield(ply)` for hooking into your gamemode.
