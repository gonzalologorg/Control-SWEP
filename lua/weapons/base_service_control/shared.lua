AddCSLuaFile("modules/movement.lua")
AddCSLuaFile("modules/thirdperson.lua")
AddCSLuaFile("modules/upgrades.lua")
AddCSLuaFile("modules/combat.lua")
AddCSLuaFile("modules/hud.lua")

include("modules/movement.lua")
include("modules/upgrades.lua")
include("modules/combat.lua")

SWEP.Base = "weapon_base"
SWEP.PrintName = "Service Gun"
SWEP.Category = "Control"
SWEP.Author = "Gonzo"
SWEP.Spawnable = true

SWEP.Slot = 1
SWEP.SlotPos = 0
SWEP.DrawAmmo = false

SWEP.MaxEnergy = 100
SWEP.DashEnergyCost = 10
SWEP.GrabPropCost = 20
SWEP.MaxBullets = 12

local noloop = false
function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "AimRight")
    self:NetworkVar("Bool", 1, "IronSight")
    self:NetworkVar("Bool", 2, "Dashing")
    self:NetworkVar("Bool", 3, "Floating")
    self:NetworkVar("Bool", 4, "EnergyDrain")
    self:NetworkVar("Bool", 5, "BulletDrain")
    self:NetworkVar("Float", 0, "DashEnd")
    self:NetworkVar("Float", 1, "EnergyRecharge")
    self:NetworkVar("Float", 2, "BulletRecharge")
    self:NetworkVar("Int", 0, "FloatAmount")
    self:NetworkVar("Int", 1, "Energy")
    self:NetworkVar("Int", 2, "Bullets")
    self:NetworkVar("Entity", 0, "Grabbing")

    self:SetAimRight(true)
    self:SetEnergy(100)
    self:SetBullets(self.MaxBullets)

    self:NetworkVarNotify("IronSight", function(s, n, o, new)
        s:SetHoldType(new and "revolver" or "pistol")
    end)

    self:NetworkVarNotify("Grabbing", function(s, n, o, new)
        s:SetHoldType(IsValid(new) and "magic" or "pistol")
    end)

    self:NetworkVarNotify("Energy", function(s, n, o, new)
        if noloop then return end
        if new < o then
            s:SetEnergyRecharge(CurTime() + 2.5)
            if new <= 0 then
                s:SetEnergyDrain(true)
                noloop = true
                s:SetEnergy(0)
                noloop = false
            end
        end

        if new >= s.MaxEnergy then
            s.ShouldHideEnergyAt = RealTime() + 1
            s:SetEnergyDrain(false)
        end
    end)

    self:PostSetupDataTables()
end

function SWEP:Initialize()
    if CLIENT then
        self:InitClient()
    else
        self:InitServer()
    end

    self:SetupMovement()
    self:SetupCombat()
end

SWEP.Events = {}
function SWEP:AddHook(event, cb)
    self.Events[event] = cb
    hook.Add(event, self, cb)
end

function SWEP:Holster()
    if IsValid(self:GetGrabbing()) then
        self:ThrowProp()
    end
    for k, v in pairs(self.Events) do
        hook.Remove(k, self)
    end

    return true
end

function SWEP:Deploy()
    for k, v in pairs(self.Events) do
        hook.Add(k, self, v)
    end
end

function SWEP:OnReloaded()
    self:Initialize()
end

function SWEP:DoChargeBullets()
    if self:GetBullets() < self.MaxBullets and self.NextBulletCharge < CurTime() and self:GetBulletRecharge() < CurTime() then
        self:SetBullets(math.min(self.MaxBullets, self:GetBullets() + 1))
        self.NextBulletCharge = CurTime() + .15

        if self:GetBullets() == self.MaxBullets then
            self.ShouldHideArmorAt = RealTime() + 1
            if self:GetBulletDrain() then
                self:SetBulletDrain(false)
            end
        end
    end
end

function SWEP:GrabThink()
    local ent = self:GetGrabbing()
    if not IsValid(ent) then
        if self:GetEnergy() >= self.MaxEnergy then return end
        if self.NextEnergyCharge < CurTime() and self:GetEnergyRecharge() < CurTime() then
            self:SetEnergy(math.min(self.MaxEnergy, self:GetEnergy() + 1))
            self.NextEnergyCharge = CurTime() + .1
        end
        return
    end

    local forward = owner:GetShootPos() + owner:GetAimVector() * 64 + owner:GetRight() * 48

    if not ent.Working then
        local diff = (forward - ent:GetPos()):GetNormalized()
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            local mass = phys:GetMass()

            if IsValid(phys) then
                if self.ForceIncrease < 100 then
                    self.ForceIncrease = self.ForceIncrease + FrameTime() * 20
                end
                phys:ApplyForceCenter(diff * self.ForceIncrease * mass)
                phys:ApplyTorqueCenter(VectorRand() * 100)
            end
        end

        if ent:GetPos():Distance(forward) < 96 then
            ent.Working = true
            if SERVER then
                ent:EmitSound("weapons/physcannon/physcannon_pickup.wav")
            end
        end

        return
    end

    self.LerpProp = LerpVector(FrameTime() * 10, self.LerpProp or forward, forward)
    ent:SetPos(SERVER and forward or self.LerpProp)
end

SWEP.NextEnergyCharge = 0
SWEP.NextBulletCharge = 0
function SWEP:Think()
    local owner = self:GetOwner()

    if self:GetIronSight() and not owner:KeyDown(IN_ATTACK2) then
        self:SetIronSight(false)
    end

    self:DoChargeBullets()
    self:GrabThink()
end

SWEP.LerpedSide = 1
SWEP.LerpedIS = 24
function SWEP:GetDeviation()
    local owner = self:GetOwner()

    if CLIENT then
        local side = self:GetAimRight() and 1 or -1
        self.LerpedSide = Lerp(FrameTime() * 10, self.LerpedSide, side)
    end

    local val = SERVER and (self:GetAimRight() and 1 or -1) or self.LerpedSide
    if SERVER then
        val = val * (self:GetIronSight() and 16 or 24)
    else
        self.LerpedIS = Lerp(FrameTime() * 15, self.LerpedIS or 0, self:GetIronSight() and 16 or 24)
        val = val * self.LerpedIS
    end
    local start = owner:GetShootPos() + owner:GetRight() * val + owner:GetForward() * -64
    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = start,
        filter = owner
    })
    return tr.HitPos + tr.HitNormal * 4
end