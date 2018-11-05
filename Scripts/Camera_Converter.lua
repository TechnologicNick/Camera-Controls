Camera_Converter = class( nil )
Camera_Converter.maxChildCount = -1
Camera_Converter.maxParentCount = 1
Camera_Converter.connectionInput = sm.interactable.connectionType.logic
Camera_Converter.connectionOutput = sm.interactable.connectionType.logic
Camera_Converter.colorNormal = sm.color.new( 0x007fffff )
Camera_Converter.colorHighlight = sm.color.new( 0x3094ffff )
Camera_Converter.poseWeightCount = 1

Camera_Converter.uuid_gyro  = "c7ce3f96-63ef-4428-b34a-a8b9c66cc931"
Camera_Converter.uuid_Y_pos = "d99af2e3-ebb3-4f62-8371-d6204fe79b95"
Camera_Converter.uuid_Y_neg = "16be17c8-b2e1-4e95-ac7b-3986c10fb8f2"
Camera_Converter.uuid_P_pos = "17783e8e-5d4a-479d-a81e-608c9389056f"
Camera_Converter.uuid_P_neg = "f21e1396-2c17-4c67-a6d0-0773fc9de0bd"
Camera_Converter.uuid_R_pos = "59eb64fc-7cc9-49d2-ad17-59d8ac5a0af4"
Camera_Converter.uuid_R_neg = "a58b0b1b-93aa-4c26-88b8-7ead87e88fdf"

GyroSensor = class( nil )
GyroSensor.maxChildCount = -1
GyroSensor.maxParentCount = 1
GyroSensor.connectionInput = sm.interactable.connectionType.seated
GyroSensor.connectionOutput = sm.interactable.connectionType.logic
GyroSensor.colorNormal = sm.color.new( 0xff40ffff )
GyroSensor.colorHighlight = sm.color.new( 0xff80ffff )
GyroSensor.poseWeightCount = 1

if server_seat == nil then
    server_seat = {}
end

if client_converters == nil then
    client_converters = {}
end

if client_interactables == nil then
    client_interactables = {}
end

function GyroSensor.server_onFixedUpdate( self, timeStep )
    local parent = self.interactable:getSingleParent()
    
    self.interactable:setActive((parent ~= nil) and parent:isActive())
end






function Camera_Converter.client_onCreate( self )
    client_converters[self.interactable:getId()] = self
    client_interactables[self.interactable:getId()] = self.interactable
end

function Camera_Converter.client_onUpdate( self, dt )
    self.interactable:setPoseWeight(0, self.interactable:isActive() and 1 or 0)
    self.interactable:setUvFrameIndex(self.interactable:isActive() and 6 or 0)
end

function Camera_Converter.server_onFixedUpdate( self, timeStep )
    local parent = self.interactable:getSingleParent()
    
    if parent and (tostring(parent:getShape():getShapeUuid()) ~= Camera_Converter.uuid_gyro) then
        --parent:disconnect(self.interactable)
        --print(tostring(parent:getShape():getShapeUuid()), Camera_Converter.uuid_gyro)
        return
    end

    if parent and parent:isActive() then
        local isOldestChild = self:isOldestConverter(parent:getChildren())
        if isOldestChild then
            if parent:getSingleParent() then
                local player = server_getNearestPlayer(parent:getSingleParent():getShape():getWorldPosition())
                if player then
                    --Initialise 
                    local toSave = {yaw = 0, pitch = 0, roll = 0}
                    
                    local gyroFront = parent:getShape().up * -1
                    local gyroRight = parent:getShape().right
                    local gyroUp = gyroFront:cross(gyroRight) * -1
                    
                    local playerYawPitch = directionToYawPitch(player.character:getDirection())
                    local gyroYawPitch = directionToYawPitch(gyroFront)
                    
                    local seatRoll = sm.util.clamp((math.acos(gyroRight.z)-math.pi/2)/math.pi*-2, -1, 1)
                    
                    toSave = {yaw = playerYawPitch.yaw - gyroYawPitch.yaw, pitch = playerYawPitch.pitch - gyroYawPitch.pitch, roll = seatRoll}
                    
                    --Handle the part where the yaw goes from 1 to -1
                    if math.abs(toSave.yaw) > 1 then
                        if toSave.yaw > 0 then
                            toSave.yaw = (-1 + playerYawPitch.yaw) - (1 + gyroYawPitch.yaw)
                        else
                            toSave.yaw = (1 + playerYawPitch.yaw) - (-1 + gyroYawPitch.yaw)
                        end
                    end
                    
                    --Storing the yaw, pitch and roll that the converters need to use
                    server_seat[parent:getId()] = toSave
                end
            end
        end
        
        local seatData = server_seat[parent:getId()]
        local uuid = tostring(self.interactable:getShape():getShapeUuid())
        
        if seatData then
            if uuid == Camera_Converter.uuid_Y_pos then
                local power = toCameraPower(seatData.yaw)
                --print(power, seatData.yaw)
                setCameraConverterEnabled(self, power > 0,  power)
            elseif uuid == Camera_Converter.uuid_Y_neg then
                local power = toCameraPower(seatData.yaw)
                setCameraConverterEnabled(self, power < 0, -power)
            elseif uuid == Camera_Converter.uuid_P_pos then
                local power = toCameraPower(seatData.pitch)
                setCameraConverterEnabled(self, power > 0,  power)
            elseif uuid == Camera_Converter.uuid_P_neg then
                local power = toCameraPower(seatData.pitch)
                setCameraConverterEnabled(self, power < 0, -power)
            elseif uuid == Camera_Converter.uuid_R_pos then
                local power = toCameraPower(seatData.roll)
                setCameraConverterEnabled(self, power > 0,  power)
            elseif uuid == Camera_Converter.uuid_R_neg then
                local power = toCameraPower(seatData.roll)
                setCameraConverterEnabled(self, power < 0, -power)
            end
        end
    elseif parent and not parent:isActive() and isCameraConverter(self.interactable) then
        setCameraConverterEnabled(self, false, 0)
    end
end

function toCameraPower(value)
    value = value*2
    --value = sm.util.clamp(value, -1, 1)
    if math.abs(value) < 0.0001 then
        value = 0
    end
    --print(value)
    return value
end

function directionToYawPitch( direction )
    local euler = {}
    euler.yaw = math.atan2(direction.y,direction.x)/math.pi
    euler.pitch = math.acos(direction.z)/math.pi*2-1
    --print(yaw, pitch)
    return euler
end





function server_getNearestPlayer( position )
    local nearestPlayer = nil
    local nearestDistance = nil
    for id,player in pairs(sm.player.getAllPlayers()) do
        --print(id, player)
        local length2 = sm.vec3.length2(position - player.character:getWorldPosition())
        if nearestDistance == nil or length2 < nearestDistance then
            nearestDistance = length2
            nearestPlayer = player
        end
    end
    return nearestPlayer
end

function Camera_Converter.isOldestConverter( self, childList )
    local oldestInteractable = nil
    for id,interactable in pairs(childList) do
        if interactable then
            if isCameraConverter(interactable) and (oldestInteractable == nil or interactable:getId() < oldestInteractable:getId()) then
                oldestInteractable = interactable
            end
        end
    end
    return (oldestInteractable ~= nil and self.interactable:getId() == oldestInteractable:getId())
end

function isCameraConverter(interactable)
    --print(interactable)
    if not sm.exists(interactable) then
        return false
    end
    local uuid = tostring(interactable:getShape():getShapeUuid())
    return (uuid == Camera_Converter.uuid_Y_pos or
            uuid == Camera_Converter.uuid_Y_neg or
            uuid == Camera_Converter.uuid_P_pos or
            uuid == Camera_Converter.uuid_P_neg or
            uuid == Camera_Converter.uuid_R_pos or
            uuid == Camera_Converter.uuid_R_neg)
end



function setCameraConverterEnabled( self, enabled, power )
    self.interactable:setActive(enabled)
    self.interactable:setPower(power)
    
    local shouldAlwaysActive = nil
    for k,v in pairs(self.interactable:getChildren()) do
        if tostring(v:getType()) == "Controller" then
            if shouldAlwaysActive == nil then
                shouldAlwaysActive = true
            end
        else
            shouldAlwaysActive = false
        end
    end
    if shouldAlwaysActive ~= nil and shouldAlwaysActive == true then
        self.interactable:setActive(true)
    end
    
end
