--!strict
-- Камера в тесных проходах: у высоких персонажей камера упиралась в потолок и «дёргалась».
-- Режим Invisicam не приближает камеру к персонажу, а делает перекрывающие детали прозрачными.
local Players = game:GetService("Players")

local CameraController = {}

function CameraController:Start(): ()
	Players.LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
end

return CameraController
