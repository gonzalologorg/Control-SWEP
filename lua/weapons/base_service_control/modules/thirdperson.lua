
function SWEP:CalcView(ply)
    local owner = self:GetOwner()
    if not IsValid(owner) or owner != ply then return end
    if owner:GetActiveWeapon() != self then return end

    local tbl = {}

    tbl.origin = self:GetDeviation() + ply:GetRight() * ply:GetVelocity() * 0.01
    tbl.drawviewer = true

    return tbl
end

function SWEP:GetMotionBlurValues()
    local owner = self:GetOwner()
    if owner == LocalPlayer() then
        if self.ExtraFOV <= 0 then return end
        local power = self.ExtraFOV / 20
        return 0, 0, power / 2, 0
    end
end

function SWEP:Reload()

end