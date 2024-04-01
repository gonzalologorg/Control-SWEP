DEFINE_BASECLASS("weapon_base")

function SWEP:SetupCombat()
    self:AddHook("PlayerButtonDown", self.PlayerButtonDown)
end

function SWEP:PlayerButtonDown(pl, btn)
    local owner = self:GetOwner()
    if pl ~= owner then return end

    if SERVER and btn == KEY_E then
        if IsValid(self:GetGrabbing()) then
            self:ThrowProp()
        else
            if self:GetEnergyDrain() then return end
            self:FindProp(.05)
        end
    end
end

function SWEP:FindProp(size)
    if size >= 1 then return end

    local owner = self:GetOwner()
    local ent

    local cone = ents.FindInCone(owner:GetShootPos(), owner:GetAimVector(), 1000, 1 - size)
    for _, v in pairs(cone) do
        if v:GetClass() == "prop_physics" then
            local tr = util.TraceLine({
                start = owner:GetShootPos(),
                endpos = v:GetPos(),
                filter = {owner, v}
            })
            if tr.HitWorld then continue end
            ent = v
            break
        end
    end

    if not ent then
        self:FindProp(size + 0.05)
        return
    end

    self:SetHoldType("magic")
    self.ForceIncrease = 5
    self:SetGrabbing(ent)
    self:SetEnergy(self:GetEnergy() - self.GrabPropCost)

    owner:EmitSound("weapons/stunstick/stunstick_swing1.wav")
    ent:SetOwner(owner)
    ent:GetPhysicsObject():EnableGravity(false)
end

function SWEP:ThrowProp()
    local owner = self:GetOwner()
    local ent = self:GetGrabbing()

    ent.Working = false
    timer.Simple(.5, function()
        if IsValid(ent) then
            ent:SetOwner(nil)
        end
    end)

    self:SetGrabbing(nil)
    self:SetHoldType("pistol")
    self:SetEnergyRecharge(CurTime() + 2.5)

    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return end
    local mass = phys:GetMass()

    ent:EmitSound("weapons/fx/rics/ric" .. math.random(1, 4) .. ".wav", 100, 75, .25)
    phys:EnableGravity(true)
    phys:ApplyForceCenter(owner:GetAimVector() * mass * 2500)
end

function SWEP:GetAimVector()
    local owner = self:GetOwner()
    local start = owner:GetShootPos()
    local deviation = self:GetDeviation()
    local aim = owner:GetAimVector()

    local dist = owner:GetEyeTrace().HitPos:Distance(start)
    local trb = util.TraceLine({
        start = start,
        endpos = deviation + (aim * dist),
        ignoreworld = true,
        filter = owner
    })

    return (trb.HitPos - owner:EyePos()):GetNormalized()
end

function SWEP:ShootBullet(damage, num_bullets, aimcone, ammo_type, force, tracer)
    local owner = self:GetOwner()

    local bullet = {}
    bullet.Num = num_bullets
    bullet.Src = owner:GetShootPos() -- Source
    bullet.Dir = self:GetAimVector() -- Dir of bullet
    bullet.Spread = Vector(aimcone, aimcone, 0) -- Aim Cone
    bullet.Tracer = 1 -- Show a tracer on every x bullets
    bullet.Force = force or 1 -- Amount of force to give to phys objects
    bullet.Damage = damage
    bullet.AmmoType = ammo_type or self.Primary.Ammo
    owner:FireBullets(bullet)
    self:ShootEffects()

    PrintTable(bullet)
end

function SWEP:PrePrimaryAttack()
    if IsValid(self:GetGrabbing()) then
        self:ThrowProp()
        self:SetGrabbing(nil)
        return false
    end
    if self:GetBullets() <= 0 or self:GetBulletDrain() or not self:CanPrimaryAttack() then return false end
end

function SWEP:PrimaryAttack()

    local result = self:PrePrimaryAttack()
    if result == false then return end

    self:EmitSound("Weapon_AR2.Single")
    self:ShootBullet(150, 1, self:GetIronSight() and 0.01 or 0.03, self.Primary.Ammo)
    self:SetBullets(self:GetBullets() - 1)
    self:SetBulletRecharge(CurTime() + 2.5)
    if self:GetBullets() <= 0 then
        self:SetBulletDrain(true)
    end
    self.LastBullet = CurTime()

end

function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end
    self:SetIronSight(not self:GetIronSight())
end

SWEP.NextSideMove = 0
function SWEP:Reload()
    if not IsFirstTimePredicted() then return end
    if self.NextSideMove > CurTime() then return end

    self:SetAimRight(not self:GetAimRight())
    self.NextSideMove = CurTime() + 1
end

SWEP.LerpFOV = 75
SWEP.ExtraFOV = 0
function SWEP:TranslateFOV()
    if CLIENT then
        self.LerpFOV = Lerp(FrameTime() / 10, self.LerpFOV, self:GetIronSight() and 35 or 75)
    else
        self.LerpFOV = self:GetIronSight() and 35 or 75
    end

    if (self.ExtraFOV or 0) > 0 then
        self.ExtraFOV = self.ExtraFOV - FrameTime() / 2
        if self.ExtraFOV <= 0 then
            self.ExtraFOV = 0
        end
    end

    return self.LerpFOV + self.ExtraFOV
end