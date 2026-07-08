GM.Name = "Looter Shooter"
GM.Author = "Sagu"

include("modules/playerstats/sh_playerstats.lua")
include("modules/weapons/sh_weapons.lua")
include("modules/items/sh_items.lua")
include("modules/inventory/sh_inventory.lua")
include("modules/equipment/sh_equipment.lua")
include("modules/npcs/sh_npcs.lua")
include("modules/save/sh_save.lua")
include("modules/networking/sh_networking.lua")

if CLIENT then
    include("modules/ui/cl_inventory.lua")
end

