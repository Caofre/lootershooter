GM.Name = "Looter Shooter"
GM.Author = "Sagu"

-- Load order matters. "shared" files run on both realms (and are sent to
-- clients); "server" files only run on the server.
local modules = {
    {"shared", "modules/playerstats/sh_playerstats.lua"},
    {"shared", "modules/weapons/sh_weapons.lua"},
    {"shared", "modules/items/sh_items.lua"},
    {"shared", "modules/inventory/sh_inventory.lua"},
    {"shared", "modules/currency/sh_currency.lua"},
    {"shared", "modules/vendor/sh_vendor.lua"},
    {"shared", "modules/equipment/sh_equipment.lua"},
    {"shared", "modules/npcs/sh_npcs.lua"},
    {"server", "modules/npcs/sv_hubwander.lua"},
    {"server", "modules/npcs/sv_variants.lua"},
    {"server", "modules/npcs/sv_variants2.lua"},
    {"server", "modules/npcs/sv_variants3.lua"},
    {"shared", "modules/encounter/sh_encounter.lua"},
    {"shared", "modules/missions/sh_missions.lua"},
    {"server", "modules/missions/sv_missiontypes.lua"},
    {"shared", "modules/save/sh_save.lua"},
    {"shared", "modules/networking/sh_networking.lua"},
    {"shared", "modules/status/sh_status.lua"},
    {"shared", "modules/talents/sh_talents.lua"},
    {"shared", "modules/events/sh_events.lua"},
    {"shared", "modules/combat/sh_combat.lua"},
    {"shared", "modules/effects/sh_effects.lua"},
    {"shared", "modules/talents/sh_talents_extra.lua"},
    {"shared", "modules/talents/sh_talent_format.lua"},
    {"server", "modules/combat/sv_talent_support.lua"},
    {"server", "modules/combat/sv_damage_numbers.lua"},
    {"shared", "modules/gadgets/sh_gadgets.lua"},
    {"shared", "modules/gadgets/sh_gadget_talents.lua"},
    {"shared", "modules/armor/sh_armor.lua"},
    {"shared", "modules/crates/sh_crates.lua"},
    {"shared", "modules/crafting/sh_crafting.lua"}
}

-- Client interface files, in load order.
local clientFiles = {
    "modules/ui/cl_inventory.lua",
    "modules/ui/cl_npcui.lua",
    "modules/ui/cl_weaponmaker.lua",
    "modules/ui/cl_notifications.lua",
    "modules/ui/cl_inspect.lua",
    "modules/ui/cl_missionbroker.lua",
    "modules/ui/cl_hud.lua",
    "modules/ui/cl_music.lua",
    "modules/ui/cl_objectives.lua",
    "modules/ui/cl_gadgets.lua",
    "modules/ui/cl_damagenumbers.lua",
    "modules/ui/cl_crates.lua",
    "modules/ui/cl_workbench.lua",
    "modules/ui/cl_vendor.lua"
}

for _, entry in ipairs(modules) do

    local realm, path = entry[1], entry[2]

    if realm == "shared" then
        if SERVER then AddCSLuaFile(path) end
        include(path)
    elseif SERVER then
        include(path)
    end

end

for _, path in ipairs(clientFiles) do

    if SERVER then
        AddCSLuaFile(path)
    else
        include(path)
    end

end
