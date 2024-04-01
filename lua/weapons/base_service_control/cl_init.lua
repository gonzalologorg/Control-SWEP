include("shared.lua")
include("modules/thirdperson.lua")
include("modules/hud.lua")

SWEP.ViewModel = "models/weapons/v_pistol.mdl"
SWEP.WorldModel = "models/red_menace/control/props/serviceweapon/grip.mdl"

function SWEP:InitClient()
    SafeRemoveEntity(self._Model)
    self._Model = ClientsideModel(self.WorldModel)
    self._Model:SetParent(self)
    self._Model:SetNoDraw(true)

    self:AddHook("CalcView", self.CalcView)
    self:AddHook("UpdateAnimation", self.UpdateAnimation)
    self:AddHook("GetMotionBlurValues", self.GetMotionBlurValues)
end

function SWEP:OnRemove()
    SafeRemoveEntity(self._Model)
end

function SWEP:DrawWorldModel()
    local owner = self:GetOwner()
    local handBone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
    local pos, ang = owner:GetBonePosition(handBone)
    ang:RotateAroundAxis(ang:Forward(), 180)
    pos = pos + ang:Right() * -1.5 + ang:Up() * 1.5 + ang:Forward() * 2.5
    self._Model:SetPos(pos)
    self._Model:SetAngles(ang)

    self:ManipulateBones(self._Model)
    self._Model:DrawModel()
end

local didPlay = false
function SWEP:ManipulateBones(mdl)
    if not self.LastBullet then return end

    local progress = 1 - math.Clamp((CurTime() - self.LastBullet) * 10, 0, 1)
    if progress == 0 then
        mdl:SetSequence("idle")
    else
        mdl:SetSequence("reticle")
        mdl:SetCycle(progress)
    end

    if progress == 1 and not didPlay then
        didPlay = true
        local bId = mdl:LookupBone("Sights")
        local pos, ang = mdl:GetBonePosition(bId)
        local eff = EffectData()
        pos = pos + ang:Forward() * 0 + ang:Up() * 24 + ang:Right() * -4
        eff:SetStart(pos)
        eff:SetScale(.5)
        eff:SetOrigin(pos)
        ang:RotateAroundAxis(ang:Right(), -90)
        eff:SetAngles(ang)
        eff:SetFlags(4)
        util.Effect("MuzzleEffect", eff)
    end

    if progress == 0 then
        didPlay = false
    end
end

SWEP.LerpedVelocity = nil
SWEP.TurnAgain = 0
function SWEP:UpdateAnimation(pl, vel)
    local owner = self:GetOwner()
    if pl != owner then return end

    local attacking = self:GetIronSight() or pl:KeyDown(IN_ATTACK)
    if attacking or self.TurnAgain > CurTime() then
        --self.LerpedVelocity = pl:GetAngles()
        if attacking then
            self.TurnAgain = CurTime() + 1
        end

        self.LerpedVelocity = LerpAngle(FrameTime() * 20, self.LerpedVelocity or pl:GetAngles(), pl:GetAngles())
        self._lastVel = self.LerpedVelocity

        pl:SetRenderAngles(self.LerpedVelocity)
    elseif pl:GetVelocity():LengthSqr() > 1 then
        self.LerpedVelocity = LerpAngle(FrameTime() * 10, self.LerpedVelocity or vel:Angle(), vel:Angle())
        self._lastVel = self.LerpedVelocity
        pl:SetRenderAngles(self.LerpedVelocity)
        pl:SetPoseParameter("move_y", 0)
        pl:SetPoseParameter("move_x", 1)
    else
        pl:SetRenderAngles(self._lastVel or pl:GetAngles())
    end
end
