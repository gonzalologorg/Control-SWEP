AddCSLuaFile()

SWEP.Base = "base_service_control"
SWEP.PrintName = "Pierce"
SWEP.Category = "Control"
SWEP.Spawnable = true

SWEP.ViewModel = "models/weapons/v_pistol.mdl"
SWEP.WorldModel = "models/red_menace/control/props/serviceweapon/pierce.mdl"
SWEP.MaxBullets = 2
SWEP.Damage = 5000

function SWEP:PostSetupDataTables()
    self:NetworkVar("Bool", 6, "Charging")
    self:NetworkVar("Int", 3, "ChargeAmount")

    self:SetCharging(false)
    self:SetChargeAmount(0)
end

function SWEP:PrimaryAttack()

    local result = self:PrePrimaryAttack()
    if result == false then return end

    self:SetCharging(true)
    self:SetChargeAmount(0)

end

SWEP.NextPierceLoad = 0
function SWEP:Think()
    local owner = self:GetOwner()

    if self:GetIronSight() and not owner:KeyDown(IN_ATTACK2) then
        self:SetIronSight(false)
    end

    if self:GetCharging() and owner:KeyDown(IN_ATTACK) then
        if self:GetChargeAmount() <= 100 and self.NextPierceLoad < CurTime() then
            self.NextPierceLoad = CurTime() + .125
            self:SetChargeAmount(math.Clamp(self:GetChargeAmount() + 10, 0, 100))
        end

        return
    elseif not owner:KeyDown(IN_ATTACK) then
        if SERVER and self:GetChargeAmount() >= 50 then
            local power = self:GetChargeAmount() / 100
            owner:EmitSound("Weapon_AR2.Single")
            self:ShootBullet(self.Damage * power, 50, self:GetIronSight() and 0.01 or 0.03, self.Primary.Ammo)
            owner:ViewPunch(Angle(-5, 0, 0))

            self:CallOnClient("MuzzleFlashEvent")
        end
        self:SetCharging(false)
        self:SetChargeAmount(0)
    end

    self:DoChargeBullets()
    self:GrabThink()
end

function SWEP:MuzzleFlashEvent()
    local bId = 8
    local pos, ang = self._Model:GetBonePosition(bId)
    local eff = EffectData()
    pos = pos + ang:Forward() * 0 + ang:Up() * 0 + ang:Right() * 4
    eff:SetOrigin(pos)
    ang:RotateAroundAxis(ang:Right(), -90)
    eff:SetAngles(ang)
    eff:SetNormal(ang:Up())
    util.Effect("ManhackSparks", eff)

    local tr = util.TraceLine({
        start = pos,
        endpos = pos + self:GetAimVector() * 1024,
        filter = self:GetOwner()
    })

    pos = tr.HitPos
    local eff = EffectData()
    eff:SetOrigin(pos)
    ang:RotateAroundAxis(ang:Right(), -90)
    eff:SetAngles(ang)
    eff:SetNormal(tr.HitNormal)
    util.Effect("ManhackSparks", eff)
end

local bones = {
    [23] = Vector(1, -1, 0),
    [24] = Vector(1, 1, 0),
    [25] = Vector(-1, 1, 0),
    [26] = Vector(-1, -1, 0),
}

local didPlay = false
SWEP.ProgressLoad = 3
function SWEP:ManipulateBones(mdl)
    local pl = self:GetOwner()
    local attacking = self:GetIronSight() or self:GetCharging()
    if attacking then
        local target = 1 - (self:GetChargeAmount() / 50)
        self.ProgressLoad = Lerp(FrameTime() * (target < self.ProgressLoad and 50 or 2), self.ProgressLoad, target)
    elseif self.ProgressLoad < 3 then
        self.ProgressLoad = math.Approach(self.ProgressLoad, 3, FrameTime() * 100)
    end

    for bId, ang in pairs(bones) do
        mdl:ManipulateBonePosition(bId, ang * self.ProgressLoad)
    end
end