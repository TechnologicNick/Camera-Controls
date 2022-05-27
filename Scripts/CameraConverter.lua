dofile("uuids.lua")

---@class CameraConverter : ShapeClass
CameraConverter = class( nil )
CameraConverter.maxChildCount = -1
CameraConverter.maxParentCount = 1
CameraConverter.connectionInput = sm.interactable.connectionType.logic
CameraConverter.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
CameraConverter.colorNormal = sm.color.new( 0x007fffff )
CameraConverter.colorHighlight = sm.color.new( 0x3094ffff )
CameraConverter.poseWeightCount = 1

---@class GyroSensor : ShapeClass
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

g_converterData = {
    [tostring(obj_converter_yaw_pos)]   = { axis = "yaw",   multiplier =  1 },
    [tostring(obj_converter_yaw_neg)]   = { axis = "yaw",   multiplier = -1 },
    [tostring(obj_converter_pitch_pos)] = { axis = "pitch", multiplier =  1 },
    [tostring(obj_converter_pitch_neg)] = { axis = "pitch", multiplier = -1 },
    [tostring(obj_converter_roll_pos)]  = { axis = "roll",  multiplier =  1 },
    [tostring(obj_converter_roll_neg)]  = { axis = "roll",  multiplier = -1 },
}



function GyroSensor:server_onFixedUpdate( timeStep )
    local parent = self.interactable:getSingleParent()

    self.interactable:setActive((parent ~= nil) and parent:isActive())
end






function CameraConverter:client_onCreate()
    client_converters[self.interactable:getId()] = self
    client_interactables[self.interactable:getId()] = self.interactable
end

function CameraConverter:client_onUpdate( dt )
    self.interactable:setPoseWeight(0, self.interactable:isActive() and 1 or 0)
    self.interactable:setUvFrameIndex(self.interactable:isActive() and 6 or 0)
end

function CameraConverter:server_onFixedUpdate( timeStep )
    local parent = self.interactable:getSingleParent()
    
    if parent and (parent:getShape():getShapeUuid() ~= obj_gyro_sensor) then
        --parent:disconnect(self.interactable)
        --print(tostring(parent:getShape():getShapeUuid()), CameraConverter.uuid_gyro)
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
        local uuid = self.interactable:getShape():getShapeUuid()
        
        if seatData then
            if uuid == obj_converter_yaw_pos then
                local power = toCameraPower(seatData.yaw)
                self:setCameraConverterEnabled(power > 0,  power)
            elseif uuid == obj_converter_yaw_neg then
                local power = toCameraPower(seatData.yaw)
                self:setCameraConverterEnabled(power < 0, -power)
            elseif uuid == obj_converter_pitch_pos then
                local power = toCameraPower(seatData.pitch)
                self:setCameraConverterEnabled(power > 0,  power)
            elseif uuid == obj_converter_pitch_neg then
                local power = toCameraPower(seatData.pitch)
                self:setCameraConverterEnabled(power < 0, -power)
            elseif uuid == obj_converter_roll_pos then
                local power = toCameraPower(seatData.roll)
                self:setCameraConverterEnabled(power > 0,  power)
            elseif uuid == obj_converter_roll_neg then
                local power = toCameraPower(seatData.roll)
                self:setCameraConverterEnabled(power < 0, -power)
            end
        end
    elseif parent and not parent:isActive() and isCameraConverter(self.interactable) then
        self:setCameraConverterEnabled(false, 0)
    end
end

---Calculate the power output.
---Low power outputs are rounded to 0.
---@param value number The value to convert.
---@return any power The power output.
function toCameraPower(value)
    value = value*2
    --value = sm.util.clamp(value, -1, 1)
    if math.abs(value) < 0.0001 then
        value = 0
    end
    --print(value)
    return value
end

---Convert a directional vector to euler angles.
---@param direction Vec3 The normalized, directional vector.
---@return {yaw: number, pitch: number} euler The euler angles.
function directionToYawPitch( direction )
    local euler = {}
    euler.yaw = math.atan2(direction.y,direction.x)/math.pi
    euler.pitch = math.acos(direction.z)/math.pi*2-1
    --print(yaw, pitch)
    return euler
end




---Get the nearest player.
---@param position Vec3 The position to find the nearest player from.
---@return Player player The nearest player.
function server_getNearestPlayer( position )
    local nearestPlayer = nil
    local nearestDistance = nil
    for id,player in pairs(sm.player.getAllPlayers()) do
        --print(id, player)
        if sm.exists(player.character) then
            local length2 = sm.vec3.length2(position - player.character:getWorldPosition())
            if nearestDistance == nil or length2 < nearestDistance then
                nearestDistance = length2
                nearestPlayer = player
            end
        end
    end
    return nearestPlayer
end

---Check if this Camera Converter is the oldest of those connected to the Gyro Sensor.
---@param childList table<number, Interactable> The list of interactables to find the oldest converter in.
---@return boolean isOldestConverter If this converter is the oldest.
function CameraConverter:isOldestConverter( childList )
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

---Check if the interactable is a Camera Converter.
---@param interactable Interactable The interactable to check.
---@return boolean isCameraConverter If the interactable is a Camera Converter.
function isCameraConverter(interactable)
    if not sm.exists(interactable) then
        return false
    end

    return g_converterData[tostring(interactable.shape.uuid)] and true or false
end


---Sets the Camera Converter's outputs.
---@param enabled boolean
---@param power number
function CameraConverter:setCameraConverterEnabled( enabled, power )
    self.interactable.active = enabled
    self.interactable.power = power
    
    local shouldAlwaysActive = nil
    for k,v in pairs(self.interactable:getChildren()) do
        if v:hasOutputType( sm.interactable.connectionType.bearing ) then
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
