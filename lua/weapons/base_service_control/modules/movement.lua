function SWEP:SetupMovement()
    self:AddHook("Move", self.Move)
    self:AddHook("PlayerBindPress", self.BindPress)
    self:AddHook("OnPlayerJump", self.PlayerJump)
    self:AddHook("OnPlayerHitGround", self.OnPlayerHitGround)
end

function SWEP:BindPress(pl, bind, pressed)
    local owner = self:GetOwner()
    if not IsValid(owner) or pl != owner then return end

    if bind == "+duck" and pressed then
        self:DoDash()
        return true
    elseif bind == "+use" and pressed then
        return true
    end
end

function SWEP:CallProto(proto)
    if CLIENT then
        net.Start("SWEPControl.ActivateDash")
        net.WriteEntity(self)
        net.WriteUInt(1, 4)
        net.SendToServer()
        return
    end
    if proto == 1 then
        self:DoDash()
    end
end

SWEP.DashDuration = 0
SWEP.DashDirection = Vector(0, 0, 0)

function SWEP:DoDash()
    if self:GetEnergyDrain() then return end
    if SERVER then
        self:GetOwner():EmitSound("weapons/fx/nearmiss/bulletltor0" .. math.random(3, 9) .. ".wav")
        self:SetDashing(true)
        self:SetDashEnd(CurTime() + .15)

        local target = ents.Create("info_target")
        local owner = self:GetOwner()
        target:SetPos(owner:GetPos() + owner:OBBCenter())
        target.Trail = util.SpriteTrail(target, 0, Color(255, 255, 255), false, 72, 0, .5, 1, "trails/tube.vmt")
        self.TrailController = target
        self:SetEnergy(self:GetEnergy() - self.DashEnergyCost)
    end

    self.ExtraFOV = 20
    self.LerpedHull = nil
    self.TargetHull = nil

    if CLIENT then
        self:CallProto(1)
    end
end

SWEP.LerpFloatDirection = Vector(0, 0, 0)
function SWEP:GetFloatDirection()
    local owner = self:GetOwner()
    local dir = Vector(0, 0, 0)

    if owner:KeyDown(IN_MOVERIGHT) then
        dir = dir + owner:GetRight()
    end

    if owner:KeyDown(IN_MOVELEFT) then
        dir = dir - owner:GetRight()
    end

    if owner:KeyDown(IN_FORWARD) then
        dir = dir + owner:GetForward()
    end

    if owner:KeyDown(IN_BACK) then
        dir = dir - owner:GetForward()
    end

    self.LerpFloatDirection = LerpVector(FrameTime() * 10, self.LerpFloatDirection, dir * 100)
    return self.LerpFloatDirection or dir * 100
end

SWEP.LerpedHull = Vector(0, 0, 0)
SWEP.LerpFloatVelocity = 0
SWEP.NextSubstract = 0
function SWEP:Move(pl, mv)
    local owner = self:GetOwner()
    if not IsValid(owner) or pl != owner then return end

    if self:GetDashing() then
        self.DashDirection = self.DashDirection or mv:GetVelocity():GetNormalized() * Vector(1, 1, 0)
        if self.DashDirection == Vector(0, 0, 0) then
            self.DashDirection = owner:GetForward() * Vector(1, 1, 0)
        end

        if not self.TargetHull or IsFirstTimePredicted() then
            local tr = util.TraceHull({
                start = mv:GetOrigin(),
                endpos = mv:GetOrigin() + self.DashDirection * 1500 * FrameTime(),
                filter = owner,
                mins = Vector(-16, -16, 0),
                maxs = Vector(16, 16, 72),
                mask = MASK_PLAYERSOLID
            })

            self.TargetHull = tr.HitPos
            self.LerpedHull = self.LerpedHull or tr.HitPos
        else
            self.LerpedHull = LerpVector(FrameTime() * 10, self.LerpedHull, self.TargetHull)
        end

        mv:SetOrigin(SERVER and self.TargetHull or self.LerpedHull)

        if self:GetDashEnd() < CurTime() then
            mv:SetVelocity(self.DashDirection * 128)
            self:SetDashing(false)

            if IsValid(self.TrailController) then
                self.TrailController:SetPos(owner:GetPos() + owner:OBBCenter())
                SafeRemoveEntityDelayed(self.TrailController, 1)
            end
            self.DashDirection = nil
            self.TargetHull = nil
            self.LerpedHull = nil

            
            return true
        end
    elseif owner:KeyDown(IN_JUMP) and (self.StartFloating or CurTime()) < CurTime() then
        if not self:GetFloating() then
            self:SetFloating(true)
        end

        local vel = mv:GetVelocity()

        vel = self:GetFloatDirection()
        if SERVER and self.NextSubstract < CurTime() then
            self:SetFloatAmount(self:GetFloatAmount() - 5)
            self.NextSubstract = CurTime() + .1
            owner:SetGroundEntity(NULL)
        end
        if self:GetFloatAmount() > 0 then
            vel.z = 150
        elseif self:GetFloatAmount() > -200 then
            vel.z = 0
        else
            vel.z = -25
        end

        self.LerpFloatVelocity = Lerp(FrameTime(), self.LerpFloatVelocity, vel.z)
        vel.z = self.LerpFloatVelocity
        mv:SetVelocity(vel)
        return false
    elseif self:GetFloating() and (not owner:KeyDown(IN_JUMP) or owner:IsOnGround()) then
        self.StartFloating = CurTime() + .5
        self:SetFloating(false)
        self:SetFloatAmount(0)
    end


    local max = self:GetIronSight() and 75 or owner:IsSprinting() and 250 or 150
    mv:SetMaxClientSpeed(max)
    mv:SetMaxSpeed(max)
end

function SWEP:PlayerJump(ply, vel)
    local owner = self:GetOwner()

    if owner != ply then
        return
    end

    self.StartFloating = CurTime() + .5
    self:SetFloatAmount(100)
end

function SWEP:OnPlayerHitGround(ply)
    local owner = self:GetOwner()

    if owner != ply then
        return
    end

    self.StartFloating = nil
    self:SetFloating(false)
end

function SWEP:TranslateActivity( act )

	if ( self:GetOwner():IsNPC() ) then
		if ( self.ActivityTranslateAI[ act ] ) then
			return self.ActivityTranslateAI[ act ]
		end
		return -1
	end

	if ( self.ActivityTranslate[ act ] != nil ) then
        if self:GetFloating() then
            act = ACT_MP_SWIM
        end
		return self.ActivityTranslate[ act ]
	end

	return -1

end