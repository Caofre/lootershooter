include("shared.lua")

include("shared.lua")

function ENT:Draw()

    self:DrawModel()

    local pos =
        self:GetPos() +
        Vector(0,0,30)

    local ang =
        LocalPlayer():EyeAngles()

    ang:RotateAroundAxis(
        ang:Forward(),
        90
    )

    ang:RotateAroundAxis(
        ang:Right(),
        90
    )

    cam.Start3D2D(
        pos,
        Angle(0, ang.y, 90),
        0.15
    )

        local rarity =
            self:GetItemRarity()

        local color =
            LS_Items.RarityColors[rarity]
            or color_white

        draw.SimpleTextOutlined(
            rarity,
            "DermaLarge",
            0,
            -20,
            color,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            2,
            color_black
        )

        draw.SimpleTextOutlined(
            self:GetItemName(),
            "DermaDefaultBold",
            0,
            10,
            color_white,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            1,
            color_black
        )

    cam.End3D2D()

end