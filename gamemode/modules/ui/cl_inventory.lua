print("[LS] UI FILE LOADED")

LS_UI = LS_UI or {}

LS_UI.RarityColors = {

    Common = Color(200, 200, 200),

    Uncommon = Color(0, 255, 0),

    Rare = Color(0, 128, 255),

    Epic = Color(180, 0, 255),

    Legendary = Color(255, 140, 0)

}

print("[LS] LS_UI =", LS_UI)
function LS_UI.OpenInventory()

    if IsValid(LS_UI.InventoryFrame) then
        LS_UI.InventoryFrame:Remove()
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(400, 500)
    frame:Center()
    frame:SetTitle("Inventory")
    frame:MakePopup()

    LS_UI.InventoryFrame = frame

    local leftPanel = vgui.Create("DPanel", frame)
	leftPanel:Dock(LEFT)
	leftPanel:SetWide(220)
	

	local rightPanel = vgui.Create("DPanel", frame)
	rightPanel:Dock(FILL)
	rightPanel.Paint = function(self, w, h)

    draw.RoundedBox(
        4,
        0,
        0,
        w,
        h,
        Color(30, 30, 30, 255)
    )

end

	local list = vgui.Create("DListView", leftPanel)
	list:Dock(FILL)

	list:AddColumn("Item")

	local details = vgui.Create("DLabel", rightPanel)
	details:Dock(FILL)
	details:SetWrap(true)
	details:SetText("Select an item")
	details:SetTextColor(Color(255,255,255))
	details:SetFont("DermaDefaultBold")

	print("Inventory count:", #LS_ClientInventory)

for _, item in ipairs(LS_ClientInventory) do

    local line = list:AddLine(
        "[" .. item.id .. "] " ..
        item.rarity .. " " ..
        item.prefix .. " " ..
        item.weapon
    )

    line.ItemData = item

end

list.OnRowSelected = function(lst, index, line)

    print("CLICKED ITEM")

    local item = line.ItemData
	local rarityColor =
    LS_UI.RarityColors[item.rarity]
    or Color(255,255,255)

details:SetTextColor(rarityColor)

    if not item then
        print("NO ITEM DATA")
        return
    end

    local text =
        item.rarity .. " " ..
        item.prefix .. " " ..
        item.weapon ..
        "\n\n"

    for stat, value in pairs(item.stats) do

        text = text ..
            stat ..
            " +" ..
            value ..
            "%\n"

    end

    details:SetText(text)

	end
end

hook.Add(
    "PlayerButtonDown",
    "LS_OpenInventory",
    function(ply, button)

        print("BUTTON:", button)

        if button == KEY_I then

            print("OPENING INVENTORY")

            LS_UI.OpenInventory()

        end

    end
)

hook.Add("Think", "LS_InventoryKey", function()

    if input.IsKeyDown(KEY_I) then

        if not LS_UI.KeyHeld then

            LS_UI.KeyHeld = true

            LS_UI.OpenInventory()

        end

    else

        LS_UI.KeyHeld = false

    end

end)

LS_ClientInventory = {}

net.Receive(
    "LS_SendInventory",
    function()

        LS_ClientInventory =
            net.ReadTable()

        print(
            "Received",
            #LS_ClientInventory,
            "items"
        )

    end
)