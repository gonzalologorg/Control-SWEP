
local wide = 400
local x, y = ScrW() / 2 - wide / 2, 100

SWEP.ShouldHideEnergyAt = 0
SWEP.ShouldHideArmorAt = 0
SWEP.LerpEnergy = nil
function SWEP:DrawHUD()
    self:DrawAmmoHUD()
    self:DrawEnergyBar()
end

local bWide = 100
function SWEP:DrawAmmoHUD()
    if not self:GetIronSight() and self:GetBullets() >= self.MaxBullets and self.ShouldHideArmorAt < RealTime() then
        return
    elseif not self:GetIronSight() and self:GetBullets() >= self.MaxBullets then
        local alphaProgress = math.Clamp(self.ShouldHideArmorAt - RealTime(), 0, 1)
        surface.SetAlphaMultiplier(math.ease.OutExpo(alphaProgress))
    end

    local isDrain = self:GetBulletDrain()
    
    if isDrain then
        surface.SetDrawColor(255, 0, 0, 150 + 75 * math.sin(RealTime() * 10))
    else
        surface.SetDrawColor(255, 255, 255, 200)
    end
    
    local col = math.Round(bWide / self.MaxBullets) * 1
    local subx = ScrW() / 2 - col * (self.MaxBullets / 2)

    local bulNum = 1
    for i = 1, self.MaxBullets do
        local hasBullet = self:GetBullets() >= i
        if isDrain then
            surface.SetDrawColor(255, 0, 0, (hasBullet and 200 + 75 * math.sin(RealTime() * 10)) or 25)
        else
            surface.SetDrawColor(255, 255, 255, hasBullet and 200 or 25)
        end

        local sine = math.sin(((i - .5) / self.MaxBullets) * math.pi)
        draw.NoTexture()
        surface.DrawTexturedRectRotated(subx + (i - self.MaxBullets / 2) * col, ScrH() / 2 + 64 + sine * 20, col, 8, -30 + (i / self.MaxBullets) * 60)
        subx = subx + col
    end

    surface.SetAlphaMultiplier(1)
end

function SWEP:DrawEnergyBar()

    if self:GetEnergy() >= self.MaxEnergy and self.ShouldHideEnergyAt < RealTime() then
        return
    elseif self:GetEnergy() >= self.MaxEnergy then
        local alphaProgress = math.Clamp(self.ShouldHideEnergyAt - RealTime(), 0, 1)
        surface.SetAlphaMultiplier(math.ease.OutExpo(alphaProgress))
    end

    local isDrain = self:GetEnergyDrain()
    surface.SetDrawColor(255, 255, 255, 25)
    surface.DrawRect(x, y, wide, 20)

    local progress = self:GetEnergy() / self.MaxEnergy
    self.LerpEnergy = Lerp(FrameTime() * 5, self.LerpEnergy or progress, progress)
    if isDrain then
        surface.SetDrawColor(255, 0, 0, 150 + 75 * math.sin(RealTime() * 10))
    else
        surface.SetDrawColor(255, 255, 255, 200)
    end
    surface.DrawRect(x, y, wide * self.LerpEnergy, 20)
    surface.SetAlphaMultiplier(1)
end