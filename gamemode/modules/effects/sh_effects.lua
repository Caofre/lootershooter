LS_Effects = {}

function LS_Effects.TeslaBeam(startPos, endPos)

    local effect = EffectData()

    effect:SetStart(startPos)
    effect:SetOrigin(endPos)

    util.Effect("ToolTracer", effect, true, true)

end