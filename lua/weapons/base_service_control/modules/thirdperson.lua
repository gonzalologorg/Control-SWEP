
function SWEP:CalcView(ply)
    local owner = self:GetOwner()
    if not IsValid(owner) or owner != ply then return end
    if owner:GetActiveWeapon() != self then return end

    local tbl = {}

    tbl.origin = self:GetDeviation() + ply:GetRight() * ply:GetVelocity() * 0.01
    tbl.drawviewer = true

    return tbl
end


function SWEP:Reload()

end