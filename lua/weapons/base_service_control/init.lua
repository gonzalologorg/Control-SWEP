AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("SWEPControl.ActivateDash")

function SWEP:InitServer()
end

net.Receive("SWEPControl.ActivateDash", function(l, ply)
    local wep, proto = net.ReadEntity(), net.ReadUInt(4)

    if wep:GetOwner() == ply then
        wep:CallProto(proto)
    end
end)