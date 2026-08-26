repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character
local hrp

local running = false
local riotRunning = false
local returnHomeEnabled = false

local orientationOffsetEnabled = false
local orientationOffsetPitch = 0
local orientationOffsetYaw = 0
local orientationOffsetRoll = 0
local orientationOffsetConnection = nil

local velocityPulseEnabled = false
local velocityPulseConnection = nil
local offsetDesyncEnabled = false
local burstDesyncEnabled = false
local anchorStutterEnabled = false
local desyncConnection = nil
local desyncOffsetAmount = 40
local desyncBurstPower = 1500
local desyncPulseDelay = 0.03
local desyncStutterDelay = 0.08
local desyncPulseClock = 0
local desyncBurstClock = 0
local desyncStutterClock = 0
local desyncStutterAnchored = false
local desyncOriginalAnchored = nil
local desyncPreset = "Strong"
local customJumpEnabled = false
local jumpPowerValue = 50
local originalJumpPower = nil
local originalJumpHeight = nil
local freezeCharacterEnabled = false
local previousRootAnchored = nil
local customGravityEnabled = false
local originalGravity = workspace.Gravity
local gravityValue = workspace.Gravity

local currentDistance = 500
local teleportMode = "VOID_SPAM"
local voidSpamMode = "Random Far"
local voidProfile = "Manual"
local teleportInterval = 0.035
local jitterStrength = 14

local distPlusX = 200000
local distMinusX = 200000
local distPlusY = 200000
local distMinusY = 200000
local distPlusZ = 200000
local distMinusZ = 200000

local spinSpeed = 720
local riotXJitter = 30
local riotYJitter = 8
local riotDistance = 300

local homePosition = nil
local homeCFrame = nil
local homeReturnDelay = 3
local homeReturnDistance = 10

local teleportConnection
local riotConnection
local homeConnection

local originalCFrame
local riotOriginalCFrame
local voidHideLastCFrame = nil
local lastTeleport = 0
local lastVelocityClear = 0

local voidX = math.random(-1e8, 1e8)
local voidZ = math.random(-1e8, 1e8)
local voidYOffset = 0
local voidYDir = 1
local voidDirX = math.random() * 2 - 1
local voidDirZ = math.random() * 2 - 1
local voidElapsed = 0
local voidYBase = 1e10 + math.random(-5e9, 5e9)
local voidDriftSpeed = 9e6
local voidYDriftSpeed = 4e6
local voidYDriftRange = 2e9
local voidChaos = 0.98

local function resetVoidPattern()
	voidX = math.random(-1e8, 1e8)
	voidZ = math.random(-1e8, 1e8)
	voidYOffset = 0
	voidYDir = 1
	voidDirX = math.random() * 2 - 1
	voidDirZ = math.random() * 2 - 1
	voidElapsed = 0
	voidYBase = 1e10 + math.random(-5e9, 5e9)
end

local function notify(text)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Project Rose",
			Text = tostring(text),
			Duration = 5,
		})
	end)
end

local function disconnect(conn)
	if conn then
		conn:Disconnect()
	end

	return nil
end

local function updateChar(newCharacter)
	character = newCharacter
	hrp = nil
	originalJumpPower = nil
	originalJumpHeight = nil
	previousRootAnchored = nil
	desyncOriginalAnchored = nil
	desyncStutterAnchored = false

	if character then
		hrp = character:WaitForChild("HumanoidRootPart", 5)
	end
end

if player.Character then
	updateChar(player.Character)
end

player.CharacterAdded:Connect(updateChar)
player.CharacterRemoving:Connect(function()
	updateChar(nil)
end)

local SAFE_FLOOR = 2
local SAFE_MAX_RISE = 800

local function safeTeleport(pos)
	if not hrp then
		return
	end

	local x = pos.X
	local y = math.clamp(pos.Y, SAFE_FLOOR, hrp.Position.Y + SAFE_MAX_RISE)
	local z = pos.Z

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = character and { character } or {}

	local hit = workspace:Raycast(Vector3.new(x, y + 500, z), Vector3.new(0, -1000, 0), params)
	if hit then
		y = math.max(hit.Position.Y + 3, SAFE_FLOOR)
	end

	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(x, y, z)
end

local function rawVoidTeleport(pos)
	if not hrp then
		return
	end

	if tick() - lastVelocityClear > 0.2 then
		lastVelocityClear = tick()
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end

	hrp.CFrame = CFrame.new(pos)
end

local function getVoidHidePosition()
	if not hrp then
		return nil
	end

	return Vector3.new(
		hrp.Position.X + 2e15,
		999999,
		hrp.Position.Z + 2e15
	)
end

local function getDirectionalLimitOffset()
	local raw = Vector3.new(
		math.random(-distMinusX, distPlusX),
		math.random(-distMinusY, distPlusY),
		math.random(-distMinusZ, distPlusZ)
	)

	if raw.Magnitude <= 0 then
		return Vector3.zero
	end

	return raw.Unit * math.min(raw.Magnitude, currentDistance)
end

local function computeVoidDriftDir(t)
	local nx = 0
	local nz = 0
	local amplitude = 1
	local frequency = 0.0001

	for _ = 1, 4 do
		nx += math.noise(t * frequency, 0) * amplitude
		nz += math.noise(0, t * frequency) * amplitude
		frequency *= 2.37
		amplitude *= 0.5
	end

	nx += math.sin(t * 0.00213) * math.cos(t * 0.00344) * 0.2
	nz += math.cos(t * 0.00131) * math.sin(t * 0.00579) * 0.2

	local len = math.sqrt(nx * nx + nz * nz)
	if len < 0.001 then
		return math.cos(t * 0.1), math.sin(t * 0.1)
	end

	return nx / len, nz / len
end

local function getFarVoidPosition(dt)
	voidElapsed += dt

	if voidSpamMode == "Still Point" then
		return Vector3.new(voidX, voidYBase + voidYOffset, voidZ)
	end

	if voidSpamMode == "Slow Drift" then
		local dx, dz = computeVoidDriftDir(voidElapsed)

		voidDirX += (dx - voidDirX) * voidChaos * dt * 10
		voidDirZ += (dz - voidDirZ) * voidChaos * dt * 10

		voidX += voidDirX * voidDriftSpeed * dt
		voidZ += voidDirZ * voidDriftSpeed * dt

		voidYOffset += voidYDir * voidYDriftSpeed * dt
		if math.abs(voidYOffset) >= voidYDriftRange then
			voidYDir = -voidYDir
		end

		return Vector3.new(voidX, voidYBase + voidYOffset, voidZ)
	end

	if voidSpamMode == "Circle" then
		local r = math.max(currentDistance * 1000, 1e9) * (1 + math.sin(voidElapsed))
		return Vector3.new(
			voidX + math.cos(voidElapsed * 3) * r,
			voidYBase + voidYOffset,
			voidZ + math.sin(voidElapsed * 3) * r
		)
	end

	if voidSpamMode == "Figure Eight" then
		local r = math.max(currentDistance * 2000, 2e9)
		return Vector3.new(
			voidX + math.sin(voidElapsed * 2) * r,
			voidYBase + math.sin(voidElapsed * 4) * r * 0.1,
			voidZ + math.sin(voidElapsed * 3) * r
		)
	end

	if voidSpamMode == "Wide Sweep" then
		local t = voidElapsed * 15
		local r = math.max(currentDistance * 10000, 1e10)
		return Vector3.new(
			voidX + math.sin(t) * r,
			voidYBase + math.cos(t * 1.5) * r * 0.1,
			voidZ + math.cos(t) * r
		)
	end

	if voidSpamMode == "Fast Bounce" then
		local t = voidElapsed * 50
		local r = math.max(currentDistance * 10000, 1e10) * math.sin(t)
		return Vector3.new(
			voidX + r,
			voidYBase + math.cos(t) * 1e10,
			voidZ + r
		)
	end

	if voidSpamMode == "Blink" then
		if tick() % 0.1 < 0.05 then
			return Vector3.new(voidX * 2, voidYBase + 1e11, voidZ * 2)
		end

		return Vector3.new(voidX, voidYBase, voidZ)
	end

	if voidSpamMode == "Grid Hop" then
		local cell = math.max(currentDistance * 5000, 5e8)
		local step = math.floor(voidElapsed * 8)
		local gx = (step % 5) - 2
		local gz = (math.floor(step / 5) % 5) - 2
		local gy = (step % 2 == 0) and 0 or cell * 0.18

		return Vector3.new(voidX + gx * cell, voidYBase + gy, voidZ + gz * cell)
	end

	if voidSpamMode == "Height Wave" then
		local t = voidElapsed * 6
		local r = math.max(currentDistance * 3000, 2e9)

		return Vector3.new(
			voidX + math.cos(t * 0.4) * r,
			voidYBase + math.sin(t) * r * 0.35,
			voidZ + math.sin(t * 0.4) * r
		)
	end

	if voidSpamMode == "Square Loop" then
		local r = math.max(currentDistance * 4000, 3e9)
		local t = (voidElapsed * 1.8) % 4
		local side = math.floor(t)
		local a = t - side
		local x
		local z

		if side == 0 then
			x = -r + a * 2 * r
			z = -r
		elseif side == 1 then
			x = r
			z = -r + a * 2 * r
		elseif side == 2 then
			x = r - a * 2 * r
			z = r
		else
			x = -r
			z = r - a * 2 * r
		end

		return Vector3.new(voidX + x, voidYBase + math.sin(voidElapsed * 8) * r * 0.05, voidZ + z)
	end

	if voidSpamMode == "Cross Sweep" then
		local r = math.max(currentDistance * 6000, 4e9)
		local t = voidElapsed * 4
		local axis = math.floor(t) % 4
		local a = math.sin(t * math.pi) * r

		if axis == 0 then
			return Vector3.new(voidX + a, voidYBase, voidZ)
		elseif axis == 1 then
			return Vector3.new(voidX, voidYBase + math.sin(t) * r * 0.08, voidZ + a)
		elseif axis == 2 then
			return Vector3.new(voidX - a, voidYBase, voidZ)
		end

		return Vector3.new(voidX, voidYBase - math.sin(t) * r * 0.08, voidZ - a)
	end

	if voidSpamMode == "Stacked Steps" then
		local cell = math.max(currentDistance * 3500, 2e9)
		local step = math.floor(voidElapsed * 7)
		local x = ((step % 7) - 3) * cell
		local z = ((math.floor(step / 7) % 7) - 3) * cell
		local y = (step % 5) * cell * 0.12

		return Vector3.new(voidX + x, voidYBase + y, voidZ + z)
	end

	if voidSpamMode == "Noise Cloud" then
		local r = math.max(currentDistance * 5000, 4e9)
		local t = voidElapsed * 1.5

		return Vector3.new(
			voidX + math.noise(t, 0, 0) * r,
			voidYBase + math.noise(0, t, 0) * r * 0.25,
			voidZ + math.noise(0, 0, t) * r
		)
	end

	local r = math.max(currentDistance * 10000, 1e11)
	local sign = math.random() > 0.5 and 1 or -1
	local jitter = Vector3.new(
		math.random(-1e9, 1e9),
		math.random(-1e8, 1e8),
		math.random(-1e9, 1e9)
	)

	return Vector3.new(voidX + r * sign, voidYBase + jitter.Y, voidZ + r * sign) + jitter
end

local function performVoidStep(dt, phase)
	if not hrp then
		return false
	end

	dt = dt or teleportInterval
	phase = phase or (voidElapsed + dt * 28)

	if teleportMode == "VOID_HIDE" then
		if not voidHideLastCFrame then
			voidHideLastCFrame = hrp.CFrame
		end

		local hidePos = getVoidHidePosition()
		if hidePos then
			rawVoidTeleport(hidePos)
		end

		return true
	end

	if teleportMode == "VOID_SPAM" then
		rawVoidTeleport(getFarVoidPosition(dt))
		return true
	end

	local offset

	if teleportMode == "FORWARD" then
		offset = hrp.CFrame.LookVector * currentDistance
	elseif teleportMode == "CAMERA" and workspace.CurrentCamera then
		offset = workspace.CurrentCamera.CFrame.LookVector * currentDistance
	elseif teleportMode == "DIRECTIONAL" then
		offset = getDirectionalLimitOffset()
	else
		local r1 = currentDistance * (0.60 + 0.40 * math.sin(phase * 2.3))
		local r2 = currentDistance * (0.25 + 0.15 * math.sin(phase * 5.7))
		local r3 = currentDistance * (0.10 + 0.10 * math.sin(phase * 11.3))

		local oX = math.cos(phase * 7.1) * r1 + math.cos(phase * 13.4) * r2 + math.cos(phase * 21.9) * r3
		local oZ = math.sin(phase * 7.1) * r1 + math.sin(phase * 13.4) * r2 + math.sin(phase * 21.9) * r3
		local oY = math.sin(phase * 9) * r1 * 0.4 + math.sin(phase * 17) * r2 * 0.3

		local jX = math.noise(phase * 6, 0, 0) * jitterStrength * 3 + (math.random() - 0.5) * jitterStrength * 2.5
		local jY = math.noise(0, phase * 6, 0) * jitterStrength * 1.5 + (math.random() - 0.5) * jitterStrength * 1.2
		local jZ = math.noise(0, 0, phase * 6) * jitterStrength * 3 + (math.random() - 0.5) * jitterStrength * 2.5

		offset = Vector3.new(oX + jX, oY + jY, oZ + jZ)
	end

	safeTeleport(hrp.Position + offset)
	return true
end

local function startTeleport()
	teleportConnection = disconnect(teleportConnection)

	if hrp then
		originalCFrame = hrp.CFrame
	end

	local phase = 0

	teleportConnection = RunService.Heartbeat:Connect(function(dt)
		if not running or not hrp then
			return
		end

		if tick() - lastTeleport < teleportInterval then
			return
		end

		lastTeleport = tick()
		phase += dt * 28

		performVoidStep(dt, phase)
	end)
end

local function stopTeleport()
	teleportConnection = disconnect(teleportConnection)

	if teleportMode == "VOID_HIDE" and hrp and voidHideLastCFrame then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = voidHideLastCFrame
		voidHideLastCFrame = nil
	elseif hrp and originalCFrame then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = originalCFrame
	end

	originalCFrame = nil
end

local function startRiot()
	riotConnection = disconnect(riotConnection)

	if hrp then
		riotOriginalCFrame = hrp.CFrame
	end

	local t0 = tick()
	local seed = math.random(1000, 9999)

	riotConnection = RunService.Heartbeat:Connect(function(dt)
		if not riotRunning or not hrp then
			return
		end

		local t = tick() - t0
		local spread = riotDistance / 300

		local yaw = math.rad(spinSpeed * dt)
		local pitch = math.rad(spinSpeed * 0.37 * dt * math.sin(t * 3.1))
		local roll = math.rad(spinSpeed * 0.19 * dt * math.cos(t * 5.7 + seed))

		local spinCF = hrp.CFrame * CFrame.Angles(pitch, yaw, roll)

		local jX = (math.random() - 0.5) * riotXJitter * spread * 2 + math.noise(t * 9, seed, 0) * riotXJitter * spread
		local jY = (math.random() - 0.5) * riotYJitter * spread + math.noise(0, t * 9, seed) * riotYJitter * spread * 0.3
		local jZ = (math.random() - 0.5) * riotXJitter * spread * 2 + math.noise(0, 0, t * 9 + seed) * riotXJitter * spread

		local newY = math.max(spinCF.Position.Y + jY, SAFE_FLOOR)
		hrp.CFrame = spinCF + Vector3.new(jX, newY - spinCF.Position.Y, jZ)
	end)
end

local function stopRiot()
	riotConnection = disconnect(riotConnection)

	if hrp and riotOriginalCFrame then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = riotOriginalCFrame
	end

	riotOriginalCFrame = nil
end

local function startVelocityPulse()
	velocityPulseConnection = disconnect(velocityPulseConnection)

	local pulseClock = 0

	velocityPulseConnection = RunService.Heartbeat:Connect(function(dt)
		if not velocityPulseEnabled or not hrp then
			return
		end

		pulseClock += dt * math.max(spinSpeed / 180, 0.1)

		local horizontal = math.clamp(riotDistance * 0.35, 0, 220)
		local lift = math.clamp(riotYJitter * 4, 0, 120)
		local vx = math.cos(pulseClock) * horizontal
		local vz = math.sin(pulseClock) * horizontal

		hrp.AssemblyLinearVelocity = Vector3.new(vx, lift, vz)
		hrp.AssemblyAngularVelocity = Vector3.new(0, math.rad(math.clamp(spinSpeed, 0, 1440)), 0)
	end)
end

local function stopVelocityPulse()
	velocityPulseConnection = disconnect(velocityPulseConnection)

	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
end

local function anyDesyncEnabled()
	return offsetDesyncEnabled or burstDesyncEnabled or anchorStutterEnabled
end

local function restoreDesyncStutter()
	if hrp and desyncOriginalAnchored ~= nil then
		hrp.Anchored = desyncOriginalAnchored
	end

	desyncOriginalAnchored = nil
	desyncStutterAnchored = false
	desyncStutterClock = 0
end

local function clearDesyncVelocity()
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
end

local function stopDesyncSystems()
	desyncConnection = disconnect(desyncConnection)
	desyncPulseClock = 0
	desyncBurstClock = 0
	clearDesyncVelocity()
	restoreDesyncStutter()
end

local function startDesyncSystems()
	if desyncConnection then
		return
	end

	desyncConnection = RunService.Heartbeat:Connect(function(dt)
		if not anyDesyncEnabled() then
			stopDesyncSystems()
			return
		end

		if not hrp then
			return
		end

		if offsetDesyncEnabled then
			desyncPulseClock += dt

			if desyncPulseClock >= desyncPulseDelay then
				desyncPulseClock = 0

				local angle = tick() * 3
				local offset = Vector3.new(
					math.sin(angle) * desyncOffsetAmount,
					math.sin(angle * 1.7) * desyncOffsetAmount * 0.35,
					math.cos(angle) * desyncOffsetAmount
				)
				local pulse = offset * 40
				local velocity = hrp.AssemblyLinearVelocity

				hrp.AssemblyLinearVelocity = Vector3.new(pulse.X, velocity.Y + pulse.Y, pulse.Z)
				task.delay(0.05, function()
					if hrp and hrp.Parent and offsetDesyncEnabled then
						clearDesyncVelocity()
					end
				end)
			end
		end

		if burstDesyncEnabled then
			desyncBurstClock += dt

			if desyncBurstClock >= 0.025 then
				desyncBurstClock = 0

				local direction = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
				if direction.Magnitude < 0.01 then
					direction = Vector3.new(1, 0, 0)
				else
					direction = direction.Unit
				end

				local velocity = hrp.AssemblyLinearVelocity
				hrp.AssemblyLinearVelocity = Vector3.new(
					direction.X * desyncBurstPower,
					velocity.Y + (math.random() - 0.5) * desyncBurstPower * 0.2,
					direction.Z * desyncBurstPower
				)

				task.delay(0.05, function()
					if hrp and hrp.Parent and burstDesyncEnabled then
						clearDesyncVelocity()
					end
				end)
			end
		end

		if anchorStutterEnabled and not freezeCharacterEnabled then
			if desyncOriginalAnchored == nil then
				desyncOriginalAnchored = hrp.Anchored
			end

			desyncStutterClock += dt
			if desyncStutterClock >= desyncStutterDelay then
				desyncStutterClock = 0
				desyncStutterAnchored = not desyncStutterAnchored
				hrp.Anchored = desyncStutterAnchored
			end
		elseif desyncOriginalAnchored ~= nil then
			restoreDesyncStutter()
		end
	end)
end

local function refreshDesyncSystems()
	if not anchorStutterEnabled and desyncOriginalAnchored ~= nil then
		restoreDesyncStutter()
	end

	if anyDesyncEnabled() then
		startDesyncSystems()
	else
		stopDesyncSystems()
	end
end

local function getHumanoid()
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function captureCharacterDefaults(humanoid)
	if not humanoid then
		return
	end

	if originalJumpPower == nil then
		originalJumpPower = humanoid.JumpPower
	end

	if originalJumpHeight == nil then
		originalJumpHeight = humanoid.JumpHeight
	end
end

local function applyPlayerSettings()
	local humanoid = getHumanoid()

	if humanoid then
		captureCharacterDefaults(humanoid)

		if customJumpEnabled then
			pcall(function()
				humanoid.UseJumpPower = true
			end)

			humanoid.JumpPower = jumpPowerValue
		end
	end
end

local function restorePlayerSettings()
	local humanoid = getHumanoid()

	if humanoid then
		if originalJumpPower then
			humanoid.JumpPower = originalJumpPower
		end

		if originalJumpHeight then
			humanoid.JumpHeight = originalJumpHeight
		end
	end
end

local function setCharacterFrozen(value)
	freezeCharacterEnabled = value

	if not hrp then
		if not value then
			previousRootAnchored = nil
		end

		return
	end

	if value then
		if previousRootAnchored == nil then
			previousRootAnchored = hrp.Anchored
		end

		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.Anchored = true
	else
		hrp.Anchored = previousRootAnchored == true
		previousRootAnchored = nil
	end
end

local function setCustomGravity(value)
	customGravityEnabled = value

	if value then
		workspace.Gravity = gravityValue
	else
		workspace.Gravity = originalGravity
	end
end

local function saveHome()
	if hrp then
		homeCFrame = hrp.CFrame
		homePosition = hrp.Position
	end
end

local function teleportHome()
	if hrp and homeCFrame then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = homeCFrame
	end
end

local function startReturnHome()
	homeConnection = disconnect(homeConnection)

	if not homeCFrame and hrp then
		saveHome()
	end

	local lastReturn = 0
	local lastHomeCheck = 0

	homeConnection = RunService.Heartbeat:Connect(function()
		if tick() - lastHomeCheck < 0.1 then
			return
		end

		lastHomeCheck = tick()

		if not returnHomeEnabled or not hrp or not homePosition or not homeCFrame then
			return
		end

		if (hrp.Position - homePosition).Magnitude > homeReturnDistance
			and tick() - lastReturn >= homeReturnDelay then
			lastReturn = tick()
			teleportHome()
		end
	end)
end

local function stopReturnHome()
	homeConnection = disconnect(homeConnection)
end

local function startOrientationOffset()
	orientationOffsetConnection = disconnect(orientationOffsetConnection)

	local baseLook

	if hrp then
		baseLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		if baseLook.Magnitude < 0.01 then
			baseLook = Vector3.new(0, 0, -1)
		else
			baseLook = baseLook.Unit
		end
	end

	orientationOffsetConnection = RunService.Heartbeat:Connect(function()
		if not orientationOffsetEnabled or not hrp then
			return
		end

		local look = baseLook or Vector3.new(0, 0, -1)
		local base = CFrame.lookAt(hrp.Position, hrp.Position + look)
		hrp.CFrame = base * CFrame.Angles(
			math.rad(orientationOffsetPitch),
			math.rad(orientationOffsetYaw),
			math.rad(orientationOffsetRoll)
		)
	end)
end

local function stopOrientationOffset()
	orientationOffsetConnection = disconnect(orientationOffsetConnection)
end

local OBSIDIAN_REPO = "https://raw.githubusercontent.com/uhfork/Obsidian/main/"

local function requireUiModule(name)
	local candidates = {}

	if script and typeof(script) == "Instance" then
		local localModule = script:FindFirstChild(name)
		if localModule then
			table.insert(candidates, localModule)
		end
	end

	local replicatedModule = ReplicatedStorage:FindFirstChild(name)
	if replicatedModule then
		table.insert(candidates, replicatedModule)
	end

	for _, module in ipairs(candidates) do
		if module:IsA("ModuleScript") then
			local ok, result = pcall(function()
				return require(module)
			end)

			if ok and type(result) == "table" then
				return result
			end
		end
	end

	return nil
end

local function loadRemoteLua(path)
	if type(loadstring) ~= "function" then
		return nil, "loadstring is unavailable"
	end

	local ok, result = pcall(function()
		return loadstring(game:HttpGet(OBSIDIAN_REPO .. path))()
	end)

	if ok then
		return result
	end

	return nil, result
end

local function loadObsidian()
	local Library = requireUiModule("Obsidian") or requireUiModule("Library")
	local ThemeManager = requireUiModule("ThemeManager")
	local SaveManager = requireUiModule("SaveManager")

	if not Library then
		local result, err = loadRemoteLua("Library.lua")
		if type(result) == "table" then
			Library = result
		else
			error("Obsidian not found. Add a ModuleScript named 'Obsidian' or 'Library', or enable HttpGet/loadstring. Remote error: " .. tostring(err))
		end
	end

	if not ThemeManager then
		local result = loadRemoteLua("addons/ThemeManager.lua")
		if type(result) == "table" then
			ThemeManager = result
		end
	end

	if not SaveManager then
		local result = loadRemoteLua("addons/SaveManager.lua")
		if type(result) == "table" then
			SaveManager = result
		end
	end

	return Library, ThemeManager, SaveManager
end

local function safeSetValue(element, value)
	if element and type(element.SetValue) == "function" then
		element:SetValue(value)
	end
end

local shaderEnabled = false
local shaderPreset = "Cyber"
local shaderEffects = {}
local originalLighting = nil

local SHADER_PRESETS = {
	Cyber = {
		Brightness = 2.4,
		Contrast = 0.35,
		Saturation = 0.2,
		TintColor = Color3.fromRGB(185, 210, 255),
		BloomIntensity = 0.45,
		BloomSize = 36,
		SunRaysIntensity = 0.08,
		BlurSize = 0,
	},
	Void = {
		Brightness = 1.6,
		Contrast = 0.55,
		Saturation = -0.1,
		TintColor = Color3.fromRGB(170, 145, 255),
		BloomIntensity = 0.7,
		BloomSize = 48,
		SunRaysIntensity = 0.03,
		BlurSize = 0,
	},
	Warm = {
		Brightness = 2.1,
		Contrast = 0.25,
		Saturation = 0.25,
		TintColor = Color3.fromRGB(255, 215, 180),
		BloomIntensity = 0.35,
		BloomSize = 30,
		SunRaysIntensity = 0.1,
		BlurSize = 0,
	},
	Cold = {
		Brightness = 1.9,
		Contrast = 0.3,
		Saturation = 0.05,
		TintColor = Color3.fromRGB(170, 220, 255),
		BloomIntensity = 0.4,
		BloomSize = 34,
		SunRaysIntensity = 0.05,
		BlurSize = 0,
	},
	Cinematic = {
		Brightness = 1.7,
		Contrast = 0.45,
		Saturation = -0.05,
		TintColor = Color3.fromRGB(235, 225, 210),
		BloomIntensity = 0.25,
		BloomSize = 24,
		SunRaysIntensity = 0.12,
		BlurSize = 1,
	},
	Neon = {
		Brightness = 2.8,
		Contrast = 0.5,
		Saturation = 0.45,
		TintColor = Color3.fromRGB(190, 255, 245),
		BloomIntensity = 0.9,
		BloomSize = 56,
		SunRaysIntensity = 0.06,
		BlurSize = 0,
	},
	Moonlight = {
		Brightness = 1.45,
		Contrast = 0.38,
		Saturation = -0.18,
		TintColor = Color3.fromRGB(165, 185, 255),
		BloomIntensity = 0.28,
		BloomSize = 28,
		SunRaysIntensity = 0.02,
		BlurSize = 0,
	},
	GoldenHour = {
		Brightness = 2.25,
		Contrast = 0.32,
		Saturation = 0.3,
		TintColor = Color3.fromRGB(255, 198, 130),
		BloomIntensity = 0.5,
		BloomSize = 42,
		SunRaysIntensity = 0.18,
		BlurSize = 0,
	},
	DeepFried = {
		Brightness = 3.1,
		Contrast = 0.75,
		Saturation = 0.85,
		TintColor = Color3.fromRGB(255, 235, 185),
		BloomIntensity = 1.1,
		BloomSize = 64,
		SunRaysIntensity = 0.16,
		BlurSize = 0,
	},
	Soft = {
		Brightness = 1.9,
		Contrast = 0.12,
		Saturation = 0.08,
		TintColor = Color3.fromRGB(235, 238, 255),
		BloomIntensity = 0.18,
		BloomSize = 22,
		SunRaysIntensity = 0.04,
		BlurSize = 1,
	},
}

local function captureLighting()
	local Lighting = game:GetService("Lighting")

	if originalLighting then
		return
	end

	originalLighting = {
		Brightness = Lighting.Brightness,
		ClockTime = Lighting.ClockTime,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		FogEnd = Lighting.FogEnd,
		FogStart = Lighting.FogStart,
		FogColor = Lighting.FogColor,
		ExposureCompensation = Lighting.ExposureCompensation,
	}
end

local function clearShaders()
	local Lighting = game:GetService("Lighting")

	for _, effect in pairs(shaderEffects) do
		if effect then
			effect:Destroy()
		end
	end

	table.clear(shaderEffects)

	if originalLighting then
		for property, value in pairs(originalLighting) do
			pcall(function()
				Lighting[property] = value
			end)
		end
	end
end

local function applyShaderPreset()
	local Lighting = game:GetService("Lighting")
	local preset = SHADER_PRESETS[shaderPreset] or SHADER_PRESETS.Cyber

	captureLighting()
	clearShaders()

	Lighting.Brightness = preset.Brightness
	Lighting.ExposureCompensation = 0.15
	Lighting.ClockTime = 17.5
	Lighting.FogEnd = 100000
	Lighting.FogStart = 0

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "Ascida_ColorCorrection"
	colorCorrection.Contrast = preset.Contrast
	colorCorrection.Saturation = preset.Saturation
	colorCorrection.TintColor = preset.TintColor
	colorCorrection.Parent = Lighting
	table.insert(shaderEffects, colorCorrection)

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Ascida_Bloom"
	bloom.Intensity = preset.BloomIntensity
	bloom.Size = preset.BloomSize
	bloom.Threshold = 1
	bloom.Parent = Lighting
	table.insert(shaderEffects, bloom)

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "Ascida_SunRays"
	sunRays.Intensity = preset.SunRaysIntensity
	sunRays.Spread = 0.75
	sunRays.Parent = Lighting
	table.insert(shaderEffects, sunRays)

	if preset.BlurSize > 0 then
		local blur = Instance.new("BlurEffect")
		blur.Name = "Ascida_Blur"
		blur.Size = preset.BlurSize
		blur.Parent = Lighting
		table.insert(shaderEffects, blur)
	end
end

local function setShaderEnabled(value)
	shaderEnabled = value

	if shaderEnabled then
		applyShaderPreset()
	else
		clearShaders()
	end
end

local function loadMainUI()
	local Library, ThemeManager, SaveManager = loadObsidian()

	assert(type(Library) == "table", "Obsidian library is missing.")
	assert(type(Library.CreateWindow) == "function", "Obsidian.CreateWindow is missing.")

	local Options = Library.Options or {}
	Library.ForceCheckbox = false
	Library.ShowToggleFrameInKeybinds = false

	local Window = Library:CreateWindow({
		Title = "Ascida",
		Footer = "dsc.gg/luafans",
		Icon = "rbxthumb://type=Asset&id=124807632043990&w=150&h=150",
		IconSize = UDim2.fromOffset(52, 52),
		NotifySide = "Right",
		ShowCustomCursor = true,
		AutoShow = true,
		Center = true,
		Resizable = true,
		Glow = true,
		CornerRadius = 15,
		ShowMobileButtons = true,
		MobileButtonsSide = "Left",
	})

	Options = Library.Options or Options

	local function applyBlackWindowShadow()
		if not (Window and Window.Glow) then
			return
		end

		pcall(function()
			if type(Library.RemoveFromRegistry) == "function" then
				Library:RemoveFromRegistry(Window.Glow)
			end

			Window.Glow.ImageColor3 = Color3.fromRGB(0, 0, 0)
			Window.Glow.ImageTransparency = 0.18
			Window.Glow.Visible = true
		end)
	end

	pcall(function()
		Window:SetCornerRadius(15)
	end)
	applyBlackWindowShadow()

	local function toast(text)
		local shown = false

		if type(Library.Notify) == "function" then
			shown = pcall(function()
				Library:Notify({
					Title = "Ascida",
					Description = tostring(text),
					Time = 4,
				})
			end)
		end

		if not shown then
			notify(text)
		end
	end

	local function setupManagers(settingsTab)
		if not ThemeManager and not SaveManager then
			return
		end

		pcall(function()
			if SaveManager then
				SaveManager:SetLibrary(Library)
				SaveManager:IgnoreThemeSettings()
				SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
				SaveManager:SetFolder("Ascida")
				SaveManager:SetSubFolder(tostring(game.PlaceId))
				SaveManager:BuildConfigSection(settingsTab)
			end

			if ThemeManager then
				ThemeManager:SetLibrary(Library)
				ThemeManager:SetFolder("Ascida")

				if type(ThemeManager.AddThemeOptions) == "function" then
					ThemeManager:AddThemeOptions(settingsTab)
				elseif type(ThemeManager.ApplyToTab) == "function" then
					ThemeManager:ApplyToTab(settingsTab)
				end
			end

			if SaveManager and type(SaveManager.LoadAutoloadConfig) == "function" then
				SaveManager:LoadAutoloadConfig()
			end
		end)

		applyBlackWindowShadow()
	end

	local setToggleByIndex

	local Tabs = {
		Home = Window:AddTab("Home", "house", "ascida"),
		Void = Window:AddTab("Void", "orbit", "main shi"),
		Systems = Window:AddTab("Systems", "settings-2", "helpfull shi"),
		Settings = Window:AddTab("Settings", "settings", "luastun is hot"),
	}

	local teleportSec = Tabs.Void:AddLeftGroupbox("Void Movement", "move-3d")
	local directionSec = Tabs.Void:AddLeftGroupbox("Directional Limits", "axis-3d")
	local motionSec = Tabs.Void:AddRightGroupbox("Motion", "rotate-3d")
	local toolsSec = Tabs.Void:AddRightGroupbox("Player", "user")

	local desyncSec = Tabs.Systems:AddLeftGroupbox("Desync", "zap")
	local orientationOffsetSec = Tabs.Systems:AddLeftGroupbox("Orientation Offset", "compass")
	local homeSec = Tabs.Systems:AddRightGroupbox("Home Anchor", "home")
	local orbitSec = Tabs.Systems:AddRightGroupbox("Subject Orbit", "refresh-cw")
	local graphicsSec = Tabs.Systems:AddRightGroupbox("Graphics", "sparkles")

	local menuSec = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")
	local statusSec = Tabs.Home:AddLeftGroupbox("Runtime Status", "activity")
	local snapshotSec = Tabs.Home:AddLeftGroupbox("Stats", "list-checks")
	local quickSec = Tabs.Home:AddRightGroupbox("Quick Actions", "zap")
	local minimapSec = Tabs.Home:AddRightGroupbox("Void Minimap", "radar")

	local watermarkEnabled = true
	local coordinateWatermark = Library:AddDraggableLabel("X 0 Y 0 Z 0 - Ascida")
	coordinateWatermark:SetVisible(true)

	local minimapRange = 1000
	local minimapShowNames = true
	local minimapShowHeight = true
	local minimapSmooth = true
	local minimapSmoothFactor = 0.45
	local minimapRotateWithCamera = false
	local minimapVisibleCount = 0
	local minimapTrackedCount = 0
	local minimapNearestText = "Nearest: none"
	local minimapDots = {}
	local minimapDotPositions = {}
	local sessionStartedAt = os.clock()
	local fpsEstimate = 0
	local fpsFrameCount = 0
	local fpsTimer = 0

	local function formatDuration(seconds)
		seconds = math.max(0, math.floor(seconds))
		local minutes = math.floor(seconds / 60)
		local hours = math.floor(minutes / 60)

		seconds = seconds % 60
		minutes = minutes % 60

		if hours > 0 then
			return string.format("%02d:%02d:%02d", hours, minutes, seconds)
		end

		return string.format("%02d:%02d", minutes, seconds)
	end

	local fpsConnection = RunService.RenderStepped:Connect(function(dt)
		fpsFrameCount += 1
		fpsTimer += dt

		if fpsTimer >= 0.5 then
			fpsEstimate = fpsFrameCount / math.max(fpsTimer, 1 / 240)
			fpsFrameCount = 0
			fpsTimer = 0
		end
	end)

	local minimapRoot = Instance.new("Frame")
	minimapRoot.Name = "AscidaVoidMinimap"
	minimapRoot.BackgroundTransparency = 1
	minimapRoot.Size = UDim2.fromScale(1, 1)

	local minimapStatus = Instance.new("TextLabel")
	minimapStatus.Name = "Status"
	minimapStatus.BackgroundTransparency = 1
	minimapStatus.Size = UDim2.new(1, 0, 0, 18)
	minimapStatus.Text = "Auto range | Visible: 0"
	minimapStatus.TextColor3 = Color3.fromRGB(235, 235, 240)
	minimapStatus.Font = Enum.Font.Code
	minimapStatus.TextSize = 13
	minimapStatus.TextXAlignment = Enum.TextXAlignment.Left
	minimapStatus.Parent = minimapRoot

	local minimapArea = Instance.new("Frame")
	minimapArea.Name = "Area"
	minimapArea.Position = UDim2.new(0, 0, 0, 24)
	minimapArea.Size = UDim2.new(1, 0, 1, -24)
	minimapArea.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
	minimapArea.BorderSizePixel = 0
	minimapArea.ClipsDescendants = true
	minimapArea.Parent = minimapRoot

	local minimapCorner = Instance.new("UICorner")
	minimapCorner.CornerRadius = UDim.new(0, 10)
	minimapCorner.Parent = minimapArea

	local minimapStroke = Instance.new("UIStroke")
	minimapStroke.Color = Color3.fromRGB(35, 35, 40)
	minimapStroke.Thickness = 1
	minimapStroke.Parent = minimapArea

	local xAxis = Instance.new("Frame")
	xAxis.Name = "XAxis"
	xAxis.AnchorPoint = Vector2.new(0, 0.5)
	xAxis.Position = UDim2.fromScale(0, 0.5)
	xAxis.Size = UDim2.new(1, 0, 0, 1)
	xAxis.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	xAxis.BackgroundTransparency = 0.15
	xAxis.BorderSizePixel = 0
	xAxis.Parent = minimapArea

	local zAxis = Instance.new("Frame")
	zAxis.Name = "ZAxis"
	zAxis.AnchorPoint = Vector2.new(0.5, 0)
	zAxis.Position = UDim2.fromScale(0.5, 0)
	zAxis.Size = UDim2.new(0, 1, 1, 0)
	zAxis.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	zAxis.BackgroundTransparency = 0.15
	zAxis.BorderSizePixel = 0
	zAxis.Parent = minimapArea

	local selfDot = Instance.new("Frame")
	selfDot.Name = "Self"
	selfDot.AnchorPoint = Vector2.new(0.5, 0.5)
	selfDot.Position = UDim2.fromScale(0.5, 0.5)
	selfDot.Size = UDim2.fromOffset(8, 8)
	selfDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	selfDot.BorderSizePixel = 0
	selfDot.ZIndex = 4
	selfDot.Parent = minimapArea

	local selfCorner = Instance.new("UICorner")
	selfCorner.CornerRadius = UDim.new(1, 0)
	selfCorner.Parent = selfDot

	minimapSec:AddToggle("MinimapLabels", {
		Text = "Player Labels",
		Default = true,
		Callback = function(value)
			minimapShowNames = value

			for _, dot in pairs(minimapDots) do
				local label = dot:FindFirstChild("Label")
				if label and label:IsA("TextLabel") then
					label.Visible = minimapShowNames
				end
			end
		end,
	})

	minimapSec:AddToggle("MinimapHeights", {
		Text = "Show Height",
		Default = true,
		Callback = function(value)
			minimapShowHeight = value
		end,
	})

	minimapSec:AddToggle("MinimapSmoothing", {
		Text = "Smooth Dots",
		Default = true,
		Callback = function(value)
			minimapSmooth = value
		end,
	})

	minimapSec:AddToggle("MinimapCameraRotation", {
		Text = "Rotate With Camera",
		Default = false,
		Callback = function(value)
			minimapRotateWithCamera = value
		end,
	})

	minimapSec:AddSlider("MinimapSmoothFactor", {
		Text = "Smooth Amount",
		Default = minimapSmoothFactor,
		Min = 0.1,
		Max = 1,
		Rounding = 2,
		Callback = function(value)
			minimapSmoothFactor = value
		end,
	})

	minimapSec:AddUIPassthrough("VoidMinimapCanvas", {
		Instance = minimapRoot,
		Height = 230,
	})

	local teleportModeDropdown
	local voidPatternDropdown
	local distanceSlider
	local intervalSlider
	local jitterSlider

	local function applyVoidProfile(value)
		voidProfile = tostring(value)

		if voidProfile == "Steady Scan" then
			teleportMode = "VOID_SPAM"
			voidSpamMode = "Slow Drift"
			currentDistance = 2500000
			teleportInterval = 0.08
			jitterStrength = 4
			voidDriftSpeed = 3500000
			voidYDriftSpeed = 1600000
			voidYDriftRange = 900000000
			voidChaos = 0.55
		elseif voidProfile == "Fast Sweep" then
			teleportMode = "VOID_SPAM"
			voidSpamMode = "Cross Sweep"
			currentDistance = 12000000
			teleportInterval = 0.025
			jitterStrength = 18
			voidDriftSpeed = 12000000
			voidYDriftSpeed = 6000000
			voidYDriftRange = 3500000000
			voidChaos = 0.9
		elseif voidProfile == "Deep Void" then
			teleportMode = "VOID_SPAM"
			voidSpamMode = "Noise Cloud"
			currentDistance = 50000000
			teleportInterval = 0.04
			jitterStrength = 8
			voidDriftSpeed = 18000000
			voidYDriftSpeed = 9000000
			voidYDriftRange = 7000000000
			voidChaos = 0.75
		elseif voidProfile == "Stress Test" then
			teleportMode = "VOID_SPAM"
			voidSpamMode = "Fast Bounce"
			currentDistance = 50000000
			teleportInterval = 0.01
			jitterStrength = 45
			voidDriftSpeed = 30000000
			voidYDriftSpeed = 16000000
			voidYDriftRange = 12000000000
			voidChaos = 0.98
		else
			return
		end

		resetVoidPattern()
		safeSetValue(teleportModeDropdown, teleportMode)
		safeSetValue(voidPatternDropdown, voidSpamMode)
		safeSetValue(distanceSlider, currentDistance)
		safeSetValue(intervalSlider, teleportInterval)
		safeSetValue(jitterSlider, jitterStrength)
	end

	local teleportToggle = teleportSec:AddToggle("VoidMovement", {
		Text = "Void Movement",
		Default = false,
		Callback = function(value)
			running = value

			if value then
				startTeleport()
				toast("Void movement started.")
			else
				stopTeleport()
				toast("Void movement stopped.")
			end
		end,
	})

	teleportModeDropdown = teleportSec:AddDropdown("TeleportMode", {
		Text = "Movement Mode",
		Default = teleportMode,
		Values = { "VOID_SPAM", "VOID_HIDE", "RANDOM", "CAMERA", "FORWARD", "DIRECTIONAL" },
		Multi = false,
		Callback = function(value)
			teleportMode = tostring(value)
		end,
	})

	voidPatternDropdown = teleportSec:AddDropdown("VoidSpamMode", {
		Text = "Void Pattern",
		Default = voidSpamMode,
		Values = {
			"Random Far",
			"Still Point",
			"Slow Drift",
			"Circle",
			"Figure Eight",
			"Wide Sweep",
			"Fast Bounce",
			"Blink",
			"Grid Hop",
			"Height Wave",
			"Square Loop",
			"Cross Sweep",
			"Stacked Steps",
			"Noise Cloud",
		},
		Multi = false,
		Callback = function(value)
			voidSpamMode = tostring(value)
		end,
	})

	teleportSec:AddButton({
		Text = "Reset Pattern",
		Func = function()
			resetVoidPattern()
			toast("Pattern reset.")
		end,
	})

	distanceSlider = teleportSec:AddSlider("Distance", {
		Text = "Distance",
		Default = currentDistance,
		Min = 50,
		Max = 50000000,
		Rounding = 0,
		Suffix = " studs",
		Callback = function(value)
			currentDistance = value
		end,
	})

	intervalSlider = teleportSec:AddSlider("TeleportInterval", {
		Text = "Step Interval",
		Default = teleportInterval,
		Min = 0.01,
		Max = 2,
		Rounding = 2,
		Suffix = "s",
		Callback = function(value)
			teleportInterval = value
		end,
	})

	jitterSlider = teleportSec:AddSlider("JitterStrength", {
		Text = "Jitter Strength",
		Default = jitterStrength,
		Min = 0,
		Max = 60,
		Rounding = 0,
		Callback = function(value)
			jitterStrength = value
		end,
	})

	local distPlusXSlider
	local distMinusXSlider
	local distPlusYSlider
	local distMinusYSlider
	local distPlusZSlider
	local distMinusZSlider

	local function syncDirectionSliders()
		safeSetValue(distPlusXSlider, distPlusX)
		safeSetValue(distMinusXSlider, distMinusX)
		safeSetValue(distPlusYSlider, distPlusY)
		safeSetValue(distMinusYSlider, distMinusY)
		safeSetValue(distPlusZSlider, distPlusZ)
		safeSetValue(distMinusZSlider, distMinusZ)
	end

	distPlusXSlider = directionSec:AddSlider("DistPlusX", {
		Text = "+X Limit",
		Default = distPlusX,
		Min = 50,
		Max = 50000000,
		Rounding = 0,
		Callback = function(value)
			distPlusX = value
		end,
	})

	distMinusXSlider = directionSec:AddSlider("DistMinusX", {
		Text = "-X Limit",
		Default = distMinusX,
		Min = 50,
		Max = 50000000,
		Rounding = 0,
		Callback = function(value)
			distMinusX = value
		end,
	})

	distPlusYSlider = directionSec:AddSlider("DistPlusY", {
		Text = "+Y Limit",
		Default = distPlusY,
		Min = 50,
		Max = 50000000,
		Rounding = 0,
		Callback = function(value)
			distPlusY = value
		end,
	})

	distMinusYSlider = directionSec:AddSlider("DistMinusY", {
		Text = "-Y Limit",
		Default = distMinusY,
		Min = 50,
		Max = 50000000,
		Rounding = 0,
		Callback = function(value)
			distMinusY = value
		end,
	})

	distPlusZSlider = directionSec:AddSlider("DistPlusZ", {
		Text = "+Z Limit",
		Default = distPlusZ,
		Min = 50,
		Max = 50000000,
		Rounding = 0,
		Callback = function(value)
			distPlusZ = value
		end,
	})

	distMinusZSlider = directionSec:AddSlider("DistMinusZ", {
		Text = "-Z Limit",
		Default = distMinusZ,
		Min = 50,
		Max = 50000000,
		Rounding = 0,
		Callback = function(value)
			distMinusZ = value
		end,
	})

	local riotToggle = motionSec:AddToggle("SpinMotion", {
		Text = "Spin Motion",
		Default = false,
		Callback = function(value)
			riotRunning = value

			if value then
				startRiot()
				toast("Spin motion started.")
			else
				stopRiot()
				toast("Spin motion stopped.")
			end
		end,
	})

	motionSec:AddToggle("VelocityPulse", {
		Text = "Velocity Pulse",
		Default = false,
		Callback = function(value)
			velocityPulseEnabled = value

			if value then
				startVelocityPulse()
			else
				stopVelocityPulse()
			end
		end,
	})

	local spinSpeedSlider
	local riotXJitterSlider
	local riotYJitterSlider
	local riotDistanceSlider

	local function applyMotionPreset(value)
		local preset = tostring(value)

		if preset == "Smooth" then
			spinSpeed = 360
			riotXJitter = 10
			riotYJitter = 4
			riotDistance = 120
		elseif preset == "Wide" then
			spinSpeed = 900
			riotXJitter = 35
			riotYJitter = 10
			riotDistance = 900
		elseif preset == "Heavy" then
			spinSpeed = 2400
			riotXJitter = 75
			riotYJitter = 22
			riotDistance = 2500
		elseif preset == "Max" then
			spinSpeed = 12000
			riotXJitter = 120
			riotYJitter = 60
			riotDistance = 5000
		else
			return
		end

		safeSetValue(spinSpeedSlider, spinSpeed)
		safeSetValue(riotXJitterSlider, riotXJitter)
		safeSetValue(riotYJitterSlider, riotYJitter)
		safeSetValue(riotDistanceSlider, riotDistance)
	end

	spinSpeedSlider = motionSec:AddSlider("SpinSpeed", {
		Text = "Spin Speed",
		Default = spinSpeed,
		Min = 0,
		Max = 3000000,
		Rounding = 0,
		Suffix = " deg/s",
		Callback = function(value)
			spinSpeed = value
		end,
	})

	riotXJitterSlider = motionSec:AddSlider("RiotXJitter", {
		Text = "Horizontal Jitter",
		Default = riotXJitter,
		Min = 0,
		Max = 120,
		Rounding = 0,
		Callback = function(value)
			riotXJitter = value
		end,
	})

	riotYJitterSlider = motionSec:AddSlider("RiotYJitter", {
		Text = "Vertical Jitter",
		Default = riotYJitter,
		Min = 0,
		Max = 60,
		Rounding = 0,
		Callback = function(value)
			riotYJitter = value
		end,
	})

	riotDistanceSlider = motionSec:AddSlider("RiotDistance", {
		Text = "Spread Distance",
		Default = riotDistance,
		Min = 1,
		Max = 5000,
		Rounding = 0,
		Suffix = " studs",
		Callback = function(value)
			riotDistance = value
		end,
	})

	motionSec:AddDropdown("MotionPreset", {
		Text = "Motion Preset",
		Default = "Manual",
		Values = { "Manual", "Smooth", "Wide", "Heavy", "Max" },
		Multi = false,
		Callback = function(value)
			applyMotionPreset(value)
		end,
	})

	directionSec:AddButton({
		Text = "Mirror Limits",
		Func = function()
			local x = math.max(distPlusX, distMinusX)
			local y = math.max(distPlusY, distMinusY)
			local z = math.max(distPlusZ, distMinusZ)

			distPlusX = x
			distMinusX = x
			distPlusY = y
			distMinusY = y
			distPlusZ = z
			distMinusZ = z

			syncDirectionSliders()
			toast("Directional limits mirrored.")
		end,
	}):AddButton({
		Text = "Reset Limits",
		Func = function()
			distPlusX = 200000
			distMinusX = 200000
			distPlusY = 200000
			distMinusY = 200000
			distPlusZ = 200000
			distMinusZ = 200000

			syncDirectionSliders()
			toast("Directional limits reset.")
		end,
	})

	teleportSec:AddDropdown("VoidProfile", {
		Text = "Movement Preset",
		Default = voidProfile,
		Values = { "Manual", "Steady Scan", "Fast Sweep", "Deep Void", "Stress Test" },
		Multi = false,
		Callback = function(value)
			applyVoidProfile(value)
		end,
	})

	local jumpSlider

	toolsSec:AddToggle("CustomJump", {
		Text = "Custom Jump",
		Default = false,
		Callback = function(value)
			customJumpEnabled = value
			if not value then
				restorePlayerSettings()
			end

			applyPlayerSettings()
		end,
	})

	jumpSlider = toolsSec:AddSlider("JumpPower", {
		Text = "Jump Power",
		Default = jumpPowerValue,
		Min = 0,
		Max = 10000,
		Rounding = 0,
		Callback = function(value)
			jumpPowerValue = value
			applyPlayerSettings()
		end,
	})

	toolsSec:AddToggle("FreezeCharacter", {
		Text = "Freeze Character",
		Default = false,
		Callback = function(value)
			setCharacterFrozen(value)
		end,
	})

	local gravityToggle
	local gravitySlider
	local gravityPresetDropdown
	local gravityPreset = "Default"

	local function applyGravityPreset(value)
		gravityPreset = tostring(value)

		if gravityPreset == "Default" then
			gravityValue = originalGravity
			setCustomGravity(false)
			safeSetValue(gravityToggle, false)
		elseif gravityPreset == "Zero" then
			gravityValue = 0
			setCustomGravity(true)
			safeSetValue(gravityToggle, true)
		elseif gravityPreset == "Low" then
			gravityValue = 35
			setCustomGravity(true)
			safeSetValue(gravityToggle, true)
		elseif gravityPreset == "Moon" then
			gravityValue = 32
			setCustomGravity(true)
			safeSetValue(gravityToggle, true)
		elseif gravityPreset == "Heavy" then
			gravityValue = 400
			setCustomGravity(true)
			safeSetValue(gravityToggle, true)
		elseif gravityPreset == "Void" then
			gravityValue = 100000
			setCustomGravity(true)
			safeSetValue(gravityToggle, true)
		else
			return
		end

		safeSetValue(gravitySlider, gravityValue)
	end

	gravityToggle = toolsSec:AddToggle("CustomGravity", {
		Text = "Custom Gravity",
		Default = false,
		Callback = function(value)
			setCustomGravity(value)
		end,
	})

	gravitySlider = toolsSec:AddSlider("GravityValue", {
		Text = "Gravity",
		Default = gravityValue,
		Min = 0,
		Max = 100000,
		Rounding = 0,
		Callback = function(value)
			gravityValue = value

			if customGravityEnabled then
				workspace.Gravity = gravityValue
			end
		end,
	})

	gravityPresetDropdown = toolsSec:AddDropdown("GravityPreset", {
		Text = "Gravity Preset",
		Default = gravityPreset,
		Values = { "Default", "Zero", "Low", "Moon", "Heavy", "Void" },
		Multi = false,
		Callback = function(value)
			applyGravityPreset(value)
		end,
	})

	toolsSec:AddButton({
		Text = "Reset Gravity",
		Func = function()
			gravityPreset = "Default"
			gravityValue = originalGravity
			setCustomGravity(false)
			safeSetValue(gravityToggle, false)
			safeSetValue(gravitySlider, originalGravity)
			safeSetValue(gravityPresetDropdown, "Default")
			toast("Gravity reset.")
		end,
	})

	toolsSec:AddButton({
		Text = "Reset Player",
		Func = function()
			customJumpEnabled = false
			freezeCharacterEnabled = false
			customGravityEnabled = false
			jumpPowerValue = originalJumpPower or 50
			gravityValue = originalGravity
			restorePlayerSettings()
			setCharacterFrozen(false)
			setCustomGravity(false)
			setToggleByIndex("CustomJump", false)
			setToggleByIndex("FreezeCharacter", false)
			setToggleByIndex("CustomGravity", false)
			safeSetValue(jumpSlider, jumpPowerValue)
			safeSetValue(gravitySlider, originalGravity)
			safeSetValue(gravityPresetDropdown, "Default")
			toast("Player reset.")
		end,
	})

	orientationOffsetSec:AddToggle("OrientationOffsetEnabled", {
		Text = "Orientation Offset",
		Default = false,
		Callback = function(value)
			orientationOffsetEnabled = value

			if value then
				startOrientationOffset()
			else
				stopOrientationOffset()
			end
		end,
	})

	orientationOffsetSec:AddSlider("OrientationOffsetPitch", {
		Text = "Pitch Offset",
		Default = orientationOffsetPitch,
		Min = -180,
		Max = 180,
		Rounding = 0,
		Suffix = " deg",
		Callback = function(value)
			orientationOffsetPitch = value
		end,
	})

	orientationOffsetSec:AddSlider("OrientationOffsetYaw", {
		Text = "Yaw Offset",
		Default = orientationOffsetYaw,
		Min = -180,
		Max = 180,
		Rounding = 0,
		Suffix = " deg",
		Callback = function(value)
			orientationOffsetYaw = value
		end,
	})

	orientationOffsetSec:AddSlider("OrientationOffsetRoll", {
		Text = "Roll Offset",
		Default = orientationOffsetRoll,
		Min = -180,
		Max = 180,
		Rounding = 0,
		Suffix = " deg",
		Callback = function(value)
			orientationOffsetRoll = value
		end,
	})

	local homeAutoSaveOnSpawn = false
	local homeSpawnConnection = player.CharacterAdded:Connect(function()
		task.defer(function()
			task.wait(0.75)

			if homeAutoSaveOnSpawn and not Library.Unloaded then
				saveHome()
			end
		end)
	end)

	homeSec:AddButton({
		Text = "Save Home Position",
		Func = function()
			saveHome()

			if hrp then
				toast(string.format("Home saved: %.0f, %.0f, %.0f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
			else
				toast("No character root found.")
			end
		end,
	})

	homeSec:AddButton({
		Text = "Return Once",
		Func = function()
			teleportHome()
		end,
	})

	homeSec:AddToggle("AnchorOnSpawn", {
		Text = "Anchor On Spawn",
		Default = false,
		Callback = function(value)
			homeAutoSaveOnSpawn = value

			if value and hrp then
				saveHome()
				toast("Anchor on spawn enabled.")
			end
		end,
	})

	homeSec:AddToggle("ReturnHome", {
		Text = "Auto Return Home",
		Default = false,
		Callback = function(value)
			returnHomeEnabled = value

			if value then
				startReturnHome()
			else
				stopReturnHome()
			end
		end,
	})

	homeSec:AddSlider("HomeReturnDelay", {
		Text = "Return Delay",
		Default = homeReturnDelay,
		Min = 0.5,
		Max = 15,
		Rounding = 1,
		Suffix = "s",
		Callback = function(value)
			homeReturnDelay = value
		end,
	})

	homeSec:AddSlider("HomeReturnDistance", {
		Text = "Return Distance",
		Default = homeReturnDistance,
		Min = 1,
		Max = 100,
		Rounding = 0,
		Suffix = " studs",
		Callback = function(value)
			homeReturnDistance = value
		end,
	})

	desyncSec:AddToggle("OffsetDesync", {
		Text = "Offset Pulse",
		Default = false,
		Callback = function(value)
			offsetDesyncEnabled = value
			refreshDesyncSystems()
		end,
	})

	desyncSec:AddToggle("BurstDesync", {
		Text = "Velocity Burst",
		Default = false,
		Callback = function(value)
			burstDesyncEnabled = value
			refreshDesyncSystems()
		end,
	})

	desyncSec:AddToggle("AnchorStutter", {
		Text = "Anchor Stutter",
		Default = false,
		Callback = function(value)
			anchorStutterEnabled = value
			refreshDesyncSystems()
		end,
	})

	local desyncOffsetSlider
	local desyncBurstSlider
	local desyncPulseSlider
	local desyncStutterSlider

	local function applyDesyncPreset(value)
		desyncPreset = tostring(value)

		if desyncPreset == "Balanced" then
			desyncOffsetAmount = 30
			desyncBurstPower = 900
			desyncPulseDelay = 0.05
			desyncStutterDelay = 0.12
		elseif desyncPreset == "Strong" then
			desyncOffsetAmount = 40
			desyncBurstPower = 1500
			desyncPulseDelay = 0.03
			desyncStutterDelay = 0.08
		elseif desyncPreset == "Heavy" then
			desyncOffsetAmount = 120
			desyncBurstPower = 5000
			desyncPulseDelay = 0.015
			desyncStutterDelay = 0.04
		elseif desyncPreset == "Max" then
			desyncOffsetAmount = 260
			desyncBurstPower = 12000
			desyncPulseDelay = 0.005
			desyncStutterDelay = 0.02
		end

		safeSetValue(desyncOffsetSlider, desyncOffsetAmount)
		safeSetValue(desyncBurstSlider, desyncBurstPower)
		safeSetValue(desyncPulseSlider, desyncPulseDelay)
		safeSetValue(desyncStutterSlider, desyncStutterDelay)
	end

	desyncSec:AddDropdown("DesyncPreset", {
		Text = "Power Preset",
		Default = desyncPreset,
		Values = { "Balanced", "Strong", "Heavy", "Max" },
		Multi = false,
		Callback = function(value)
			applyDesyncPreset(value)
		end,
	})

	desyncOffsetSlider = desyncSec:AddSlider("DesyncOffsetAmount", {
		Text = "Offset Amount",
		Default = desyncOffsetAmount,
		Min = 2,
		Max = 500,
		Rounding = 0,
		Suffix = " studs",
		Callback = function(value)
			desyncOffsetAmount = value
		end,
	})

	desyncBurstSlider = desyncSec:AddSlider("DesyncBurstPower", {
		Text = "Burst Power",
		Default = desyncBurstPower,
		Min = 50,
		Max = 15000,
		Rounding = 0,
		Callback = function(value)
			desyncBurstPower = value
		end,
	})

	desyncPulseSlider = desyncSec:AddSlider("DesyncPulseDelay", {
		Text = "Pulse Delay",
		Default = desyncPulseDelay,
		Min = 0.005,
		Max = 0.25,
		Rounding = 3,
		Suffix = "s",
		Callback = function(value)
			desyncPulseDelay = value
		end,
	})

	desyncStutterSlider = desyncSec:AddSlider("DesyncStutterDelay", {
		Text = "Stutter Delay",
		Default = desyncStutterDelay,
		Min = 0.02,
		Max = 0.25,
		Rounding = 3,
		Suffix = "s",
		Callback = function(value)
			desyncStutterDelay = value
		end,
	})

	desyncSec:AddButton({
		Text = "Enable Preset",
		Func = function()
			applyDesyncPreset(desyncPreset)
			offsetDesyncEnabled = true
			burstDesyncEnabled = true
			anchorStutterEnabled = true
			setToggleByIndex("OffsetDesync", true)
			setToggleByIndex("BurstDesync", true)
			setToggleByIndex("AnchorStutter", true)
			refreshDesyncSystems()
			toast("Desync preset enabled.")
		end,
	}):AddButton({
		Text = "Stop Desync",
		Func = function()
			offsetDesyncEnabled = false
			burstDesyncEnabled = false
			anchorStutterEnabled = false
			setToggleByIndex("OffsetDesync", false)
			setToggleByIndex("BurstDesync", false)
			setToggleByIndex("AnchorStutter", false)
			stopDesyncSystems()
			toast("Desync stopped.")
		end,
	})

	local orbitEnabled = false
	local orbitConnection = nil
	local orbitAngle = 0
	local orbitTargetName = nil
	local orbitMode = "Circle"
	local orbitFaceTarget = true
	local orbitRadius = 8
	local orbitHeight = 4
	local orbitSpeed = 1.8

	local function getPlayerName(value)
		if typeof(value) == "Instance" and value:IsA("Player") then
			return value.Name
		end

		if type(value) == "string" and value ~= "" then
			return value
		end

		return nil
	end

	local function getClosestSubject()
		if not hrp then
			return nil
		end

		if orbitTargetName then
			local selected = Players:FindFirstChild(orbitTargetName)
			if selected and selected ~= player then
				return selected
			end
		end

		local closest, bestDist = nil, math.huge
		for _, subject in ipairs(Players:GetPlayers()) do
			if subject ~= player and subject.Character then
				local otherHrp = subject.Character:FindFirstChild("HumanoidRootPart")
				local otherHum = subject.Character:FindFirstChildOfClass("Humanoid")
				if otherHrp and otherHum and otherHum.Health > 0 then
					local d = (hrp.Position - otherHrp.Position).Magnitude
					if d < bestDist then
						bestDist = d
						closest = subject
					end
				end
			end
		end

		return closest
	end

	local function getOrbitOffset(angle)
		if orbitMode == "Figure Eight" then
			return Vector3.new(
				math.sin(angle) * orbitRadius,
				orbitHeight,
				math.sin(angle * 2) * orbitRadius * 0.5
			)
		end

		if orbitMode == "Vertical Wave" then
			return Vector3.new(
				math.cos(angle) * orbitRadius,
				orbitHeight + math.sin(angle * 2) * orbitRadius * 0.5,
				math.sin(angle) * orbitRadius
			)
		end

		if orbitMode == "Square" then
			local t = (angle / math.pi) % 4
			local side = math.floor(t)
			local a = t - side
			local r = orbitRadius

			if side == 0 then
				return Vector3.new(-r + a * 2 * r, orbitHeight, -r)
			elseif side == 1 then
				return Vector3.new(r, orbitHeight, -r + a * 2 * r)
			elseif side == 2 then
				return Vector3.new(r - a * 2 * r, orbitHeight, r)
			end

			return Vector3.new(-r, orbitHeight, r - a * 2 * r)
		end

		return Vector3.new(math.cos(angle) * orbitRadius, orbitHeight, math.sin(angle) * orbitRadius)
	end

	local function startOrbit()
		orbitConnection = disconnect(orbitConnection)

		orbitConnection = RunService.Heartbeat:Connect(function(dt)
			if not orbitEnabled or not hrp then
				return
			end

			local target = getClosestSubject()
			local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")

			if targetRoot then
				orbitAngle += dt * orbitSpeed
				local offset = getOrbitOffset(orbitAngle)

				local position = targetRoot.Position + offset
				if orbitFaceTarget then
					hrp.CFrame = CFrame.new(position, targetRoot.Position)
				else
					hrp.CFrame = CFrame.new(position) * (hrp.CFrame - hrp.Position)
				end
			end
		end)
	end

	local function stopOrbit()
		orbitConnection = disconnect(orbitConnection)
	end

	orbitSec:AddDropdown("OrbitTarget", {
		SpecialType = "Player",
		ExcludeLocalPlayer = true,
		Text = "Subject",
		Callback = function(value)
			orbitTargetName = getPlayerName(value)
		end,
	})

	orbitSec:AddToggle("OrbitSubject", {
		Text = "Orbit Subject",
		Default = false,
		Callback = function(value)
			orbitEnabled = value

			if value then
				startOrbit()
			else
				stopOrbit()
			end
		end,
	})

	orbitSec:AddDropdown("OrbitMode", {
		Text = "Orbit Mode",
		Default = orbitMode,
		Values = { "Circle", "Figure Eight", "Vertical Wave", "Square" },
		Multi = false,
		Callback = function(value)
			orbitMode = tostring(value)
		end,
	})

	orbitSec:AddToggle("OrbitFaceTarget", {
		Text = "Face Target",
		Default = true,
		Callback = function(value)
			orbitFaceTarget = value
		end,
	})

	orbitSec:AddSlider("OrbitRadius", {
		Text = "Orbit Radius",
		Default = orbitRadius,
		Min = 2,
		Max = 60,
		Rounding = 0,
		Suffix = " studs",
		Callback = function(value)
			orbitRadius = value
		end,
	})

	orbitSec:AddSlider("OrbitHeight", {
		Text = "Orbit Height",
		Default = orbitHeight,
		Min = -20,
		Max = 40,
		Rounding = 0,
		Suffix = " studs",
		Callback = function(value)
			orbitHeight = value
		end,
	})

	orbitSec:AddSlider("OrbitSpeed", {
		Text = "Orbit Speed",
		Default = orbitSpeed,
		Min = 0.1,
		Max = 12,
		Rounding = 1,
		Callback = function(value)
			orbitSpeed = value
		end,
	})

	orbitSec:AddButton({
		Text = "Snap To Orbit",
		Func = function()
			local target = getClosestSubject()
			local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")

			if not (hrp and targetRoot) then
				toast("No orbit subject found.")
				return
			end

			local position = targetRoot.Position + getOrbitOffset(orbitAngle)
			if orbitFaceTarget then
				hrp.CFrame = CFrame.new(position, targetRoot.Position)
			else
				hrp.CFrame = CFrame.new(position) * (hrp.CFrame - hrp.Position)
			end

			toast("Snapped to orbit.")
		end,
	})

	local shaderToggle = graphicsSec:AddToggle("LightingShader", {
		Text = "Lighting Shader",
		Default = false,
		Callback = function(value)
			setShaderEnabled(value)
		end,
	})

	graphicsSec:AddDropdown("ShaderPreset", {
		Text = "Shader Preset",
		Default = shaderPreset,
		Values = {
			"Cyber",
			"Void",
			"Warm",
			"Cold",
			"Cinematic",
			"Neon",
			"Moonlight",
			"GoldenHour",
			"DeepFried",
			"Soft",
		},
		Multi = false,
		Callback = function(value)
			shaderPreset = tostring(value)

			if shaderEnabled then
				applyShaderPreset()
			end
		end,
	})

	graphicsSec:AddButton({
		Text = "Reapply Lighting",
		Func = function()
			if shaderEnabled then
				applyShaderPreset()
				toast("Lighting reapplied.")
			else
				toast("Lighting shader is off.")
			end
		end,
	}):AddButton({
		Text = "Reset Lighting",
		Func = function()
			setShaderEnabled(false)
			safeSetValue(shaderToggle, false)
			toast("Lighting reset.")
		end,
	})


	menuSec:AddToggle("ShowCustomCursor", {
		Text = "Custom Cursor",
		Default = true,
		Callback = function(value)
			Library.ShowCustomCursor = value
		end,
	})


	menuSec:AddLabel("Menu bind")
		:AddKeyPicker("MenuKeybind", {
			Default = "RightShift",
			NoUI = true,
			Text = "Menu keybind",
		})

	Library.ToggleKeybind = Options.MenuKeybind


	setToggleByIndex = function(index, value)
		local toggles = Library.Toggles
		local toggle = toggles and toggles[index]

		if toggle and type(toggle.SetValue) == "function" then
			toggle:SetValue(value)
			return true
		end

		return false
	end

	menuSec:AddToggle("Watermark", {
		Text = "Watermark",
		Default = true,
		Callback = function(value)
			watermarkEnabled = value
			coordinateWatermark:SetVisible(value)
		end,
	})

    
	menuSec:AddButton({
		Text = "Unload UI",
		Func = function()
			if type(Library.Unload) == "function" then
				Library:Unload()
			end
		end,
	})
	quickSec:AddButton({
		Text = "Stop Movement",
		Func = function()
			setToggleByIndex("VoidMovement", false)
			setToggleByIndex("SpinMotion", false)
			setToggleByIndex("VelocityPulse", false)
			setToggleByIndex("OffsetDesync", false)
			setToggleByIndex("BurstDesync", false)
			setToggleByIndex("AnchorStutter", false)
			setToggleByIndex("CustomJump", false)
			setToggleByIndex("FreezeCharacter", false)
			setToggleByIndex("CustomGravity", false)

			running = false
			riotRunning = false
			velocityPulseEnabled = false
			offsetDesyncEnabled = false
			burstDesyncEnabled = false
			anchorStutterEnabled = false
			customJumpEnabled = false
			stopTeleport()
			stopRiot()
			stopVelocityPulse()
			stopDesyncSystems()
			restorePlayerSettings()
			setCharacterFrozen(false)
			setCustomGravity(false)
			toast("Movement stopped.")
		end,
	}):AddButton({
		Text = "Clear Velocity",
		Func = function()
			if hrp then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
				toast("Velocity cleared.")
			else
				toast("No character root found.")
			end
		end,
	})

	quickSec:AddButton({
		Text = "Save Anchor",
		Func = function()
			saveHome()

			if hrp then
				toast(string.format("Anchor saved: %.0f, %.0f, %.0f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
			else
				toast("No character root found.")
			end
		end,
	}):AddButton({
		Text = "Return Anchor",
		Func = function()
			teleportHome()
		end,
	})

	quickSec:AddButton({
		Text = "Copy Position",
		Func = function()
			if not hrp then
				toast("No character root found.")
				return
			end

			local positionText = string.format("%.2f, %.2f, %.2f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)

			if type(setclipboard) == "function" then
				setclipboard(positionText)
				toast("Position copied.")
			else
				toast(positionText)
			end
		end,
	}):AddButton({
		Text = "Refresh Character",
		Func = function()
			updateChar(player.Character)
			toast(hrp and "Character refreshed." or "Waiting for character root.")
		end,
	})

	quickSec:AddButton({
		Text = "Copy Status",
		Func = function()
			local positionText = "waiting"
			local speed = hrp and hrp.AssemblyLinearVelocity.Magnitude or 0

			if hrp then
				positionText = string.format("X %.0f Y %.0f Z %.0f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
			end

			local statusText = string.format(
				"Ascida | %s | Mode: %s | Pattern: %s | Speed: %.0f | %s",
				positionText,
				teleportMode,
				voidSpamMode,
				speed,
				minimapNearestText
			)

			if type(setclipboard) == "function" then
				setclipboard(statusText)
				toast("Status copied.")
			else
				toast(statusText)
			end
		end,
	})

	local function stateText(value)
		return value and "on" or "off"
	end

	local function getMinimapDot(targetPlayer)
		local dot = minimapDots[targetPlayer]

		if dot and dot.Parent then
			return dot
		end

		dot = Instance.new("Frame")
		dot.Name = targetPlayer.Name
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Size = UDim2.fromOffset(7, 7)
		dot.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
		dot.BorderSizePixel = 0
		dot.Visible = false
		dot.ZIndex = 5
		dot.Parent = minimapArea

		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot

		local dotLabel = Instance.new("TextLabel")
		dotLabel.Name = "Label"
		dotLabel.BackgroundTransparency = 1
		dotLabel.Position = UDim2.fromOffset(9, -5)
		dotLabel.Size = UDim2.fromOffset(120, 16)
		dotLabel.Text = targetPlayer.Name
		dotLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
		dotLabel.Font = Enum.Font.Code
		dotLabel.TextSize = 10
		dotLabel.TextXAlignment = Enum.TextXAlignment.Left
		dotLabel.Visible = minimapShowNames
		dotLabel.Parent = dot

		minimapDots[targetPlayer] = dot
		return dot
	end

	local function updateVoidMinimap()
		local areaSize = minimapArea.AbsoluteSize

		if areaSize.X <= 0 or areaSize.Y <= 0 then
			return
		end

		if not hrp then
			minimapStatus.Text = "Waiting for character root"
			minimapVisibleCount = 0
			minimapTrackedCount = 0
			minimapNearestText = "Nearest: waiting"

			for _, dot in pairs(minimapDots) do
				dot.Visible = false
			end

			return
		end

		local center = Vector2.new(areaSize.X * 0.5, areaSize.Y * 0.5)
		local radius = math.max(1, math.min(areaSize.X, areaSize.Y) * 0.5 - 8)
		local visibleCount = 0
		local seen = {}
		local entries = {}
		local farthestDistance = 0
		local nearestName = nil
		local nearestDistance = math.huge

		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				seen[other] = true

				local otherChar = other.Character
				local otherRoot = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
				local otherHumanoid = otherChar and otherChar:FindFirstChildOfClass("Humanoid")
				local dot = getMinimapDot(other)

				if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
					local relative = otherRoot.Position - hrp.Position
					local planarDistance = Vector3.new(relative.X, 0, relative.Z).Magnitude

					table.insert(entries, {
						Player = other,
						Dot = dot,
						Relative = relative,
						Distance = planarDistance,
					})

					farthestDistance = math.max(farthestDistance, planarDistance)

					if planarDistance < nearestDistance then
						nearestDistance = planarDistance
						nearestName = other.Name
					end
				else
					dot.Visible = false
				end
			end
		end

		minimapRange = math.max(1000, farthestDistance * 1.15)

		for _, entry in ipairs(entries) do
			local relative = entry.Relative
			local planarDistance = entry.Distance
			local dot = entry.Dot
			local mapRelative = Vector2.new(relative.X, relative.Z)
			if minimapRotateWithCamera and workspace.CurrentCamera then
				local look = workspace.CurrentCamera.CFrame.LookVector
				local yaw = math.atan2(look.X, look.Z)
				local cosYaw = math.cos(yaw)
				local sinYaw = math.sin(yaw)

				mapRelative = Vector2.new(
					mapRelative.X * cosYaw - mapRelative.Y * sinYaw,
					mapRelative.X * sinYaw + mapRelative.Y * cosYaw
				)
			end

			local scaled = Vector2.new(mapRelative.X / minimapRange, mapRelative.Y / minimapRange)
			local position = center + Vector2.new(
				math.clamp(scaled.X, -1, 1),
				math.clamp(scaled.Y, -1, 1)
			) * radius

			local displayPosition = position
			if minimapSmooth then
				local cached = minimapDotPositions[entry.Player] or position
				displayPosition = cached + (position - cached) * math.clamp(minimapSmoothFactor, 0.05, 1)
			end

			minimapDotPositions[entry.Player] = displayPosition
			dot.Position = UDim2.fromOffset(displayPosition.X, displayPosition.Y)
			dot.Visible = true
			visibleCount += 1

			if math.abs(relative.Y) > minimapRange * 0.2 then
				dot.BackgroundColor3 = Color3.fromRGB(90, 170, 255)
			elseif planarDistance < minimapRange * 0.25 then
				dot.BackgroundColor3 = Color3.fromRGB(85, 255, 135)
			elseif planarDistance < minimapRange * 0.65 then
				dot.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
			else
				dot.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
			end

			local label = dot:FindFirstChild("Label")
			if label and label:IsA("TextLabel") then
				label.Visible = minimapShowNames

				if minimapShowHeight then
					label.Text = string.format("%s %.1fM Y%+.0f", entry.Player.Name, planarDistance / 1000000, relative.Y)
				else
					label.Text = string.format("%s %.1fM", entry.Player.Name, planarDistance / 1000000)
				end
			end
		end

		for trackedPlayer, dot in pairs(minimapDots) do
			if not seen[trackedPlayer] then
				dot:Destroy()
				minimapDots[trackedPlayer] = nil
				minimapDotPositions[trackedPlayer] = nil
			end
		end

		minimapVisibleCount = visibleCount
		minimapTrackedCount = #entries
		minimapNearestText = nearestName
			and string.format("Nearest: %s %.1fM studs", nearestName, nearestDistance / 1000000)
			or "Nearest: none"
		minimapStatus.Text = string.format("Auto range: %.1fM studs | Visible: %d", minimapRange / 1000000, visibleCount)
	end

	local function setHomeLabel(index, text)
		local labels = Library.Labels
		local label = labels and labels[index]

		if not label then
			label = Options and Options[index]
		end

		if label and type(label.SetText) == "function" then
			label:SetText(text)
		end
	end

	statusSec:AddLabel("CharacterLabel", {
		Text = "Character: waiting",
		DoesWrap = true,
	})

	statusSec:AddLabel("PositionLabel", {
		Text = "Position: waiting for character",
		DoesWrap = true,
	})

	statusSec:AddLabel("VelocityLabel", {
		Text = "Velocity: 0 studs/s",
		DoesWrap = true,
	})

	statusSec:AddLabel("SessionLabel", {
		Text = "Session: 00:00 | FPS 0",
		DoesWrap = true,
	})

	statusSec:AddLabel("ModeLabel", {
		Text = "Mode: " .. teleportMode,
		DoesWrap = true,
	})

	statusSec:AddLabel("PatternLabel", {
		Text = "Pattern: " .. voidSpamMode,
		DoesWrap = true,
	})

	snapshotSec:AddLabel("HomeStateLabel", {
		Text = "Anchor: not saved",
		DoesWrap = true,
	})

	snapshotSec:AddLabel("MotionStateLabel", {
		Text = "Motion: idle",
		DoesWrap = true,
	})

	snapshotSec:AddLabel("SystemsStateLabel", {
		Text = "Systems: idle",
		DoesWrap = true,
	})

	snapshotSec:AddLabel("PlayerStateLabel", {
		Text = "Player: default",
		DoesWrap = true,
	})

	snapshotSec:AddLabel("GraphicsStateLabel", {
		Text = "Graphics: shader off",
		DoesWrap = true,
	})

	snapshotSec:AddLabel("PlayerCountLabel", {
		Text = "Minimap: 0 visible",
		DoesWrap = true,
	})

	snapshotSec:AddLabel("NearestPlayerLabel", {
		Text = "Nearest: none",
		DoesWrap = true,
	})

	snapshotSec:AddLabel({
		Text = "Hotkeys: T toggles void movement. R toggles spin motion.",
		DoesWrap = true,
	})

	setupManagers(Tabs.Settings)

	if type(Library.OnUnload) == "function" then
		Library:OnUnload(function()
			running = false
			riotRunning = false
			returnHomeEnabled = false
			orientationOffsetEnabled = false
			velocityPulseEnabled = false
			offsetDesyncEnabled = false
			burstDesyncEnabled = false
			anchorStutterEnabled = false
			customJumpEnabled = false
			freezeCharacterEnabled = false
			customGravityEnabled = false
			orbitEnabled = false
			watermarkEnabled = false

			stopTeleport()
			stopRiot()
			stopReturnHome()
			stopOrientationOffset()
			stopVelocityPulse()
			stopDesyncSystems()
			restorePlayerSettings()
			setCharacterFrozen(false)
			setCustomGravity(false)
			stopOrbit()
			setShaderEnabled(false)
			coordinateWatermark:SetVisible(false)
			fpsConnection = disconnect(fpsConnection)
			homeSpawnConnection = disconnect(homeSpawnConnection)

			for _, dot in pairs(minimapDots) do
				dot:Destroy()
			end

			table.clear(minimapDots)
			table.clear(minimapDotPositions)
		end)
	end

	task.spawn(function()
		while task.wait(0.1) do
			if Library.Unloaded then
				break
			end

			updateVoidMinimap()

			setHomeLabel("ModeLabel", "Mode: " .. teleportMode)
			setHomeLabel("PatternLabel", "Pattern: " .. voidSpamMode)

			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				setHomeLabel("CharacterLabel", string.format(
					"Character: %s | Health: %.0f / %.0f",
					character.Name,
					humanoid.Health,
					humanoid.MaxHealth
				))
			else
				setHomeLabel("CharacterLabel", "Character: waiting")
			end

			if hrp then
				local p = hrp.Position
				setHomeLabel("PositionLabel", string.format("Position: X %.0f | Y %.0f | Z %.0f", p.X, p.Y, p.Z))

				if watermarkEnabled then
					coordinateWatermark:SetText(string.format("X %.0f Y %.0f Z %.0f - Ascida", p.X, p.Y, p.Z))
				end
			else
				setHomeLabel("PositionLabel", "Position: waiting for character")

				if watermarkEnabled then
					coordinateWatermark:SetText("X 0 Y 0 Z 0 - Ascida")
				end
			end

			local speed = hrp and hrp.AssemblyLinearVelocity.Magnitude or 0
			setHomeLabel("VelocityLabel", string.format("Velocity: %.0f studs/s", speed))
			setHomeLabel("SessionLabel", string.format(
				"Session: %s | FPS %.0f",
				formatDuration(os.clock() - sessionStartedAt),
				fpsEstimate
			))

			if homePosition and hrp then
				setHomeLabel("HomeStateLabel", string.format(
					"Anchor: saved | Distance: %.0f studs | Auto return: %s",
					(hrp.Position - homePosition).Magnitude,
					stateText(returnHomeEnabled)
				))
			elseif homePosition then
				setHomeLabel("HomeStateLabel", "Anchor: saved | Waiting for character")
			else
				setHomeLabel("HomeStateLabel", "Anchor: not saved")
			end

			setHomeLabel("MotionStateLabel", string.format(
				"Motion: void %s | spin %s | pulse %s",
				stateText(running),
				stateText(riotRunning),
				stateText(velocityPulseEnabled)
			))

			setHomeLabel("SystemsStateLabel", string.format(
				"Systems: orientation %s | orbit %s | desync %s (%s)",
				stateText(orientationOffsetEnabled),
				stateText(orbitEnabled),
				stateText(anyDesyncEnabled()),
				desyncPreset
			))

			if freezeCharacterEnabled and hrp and not hrp.Anchored then
				setCharacterFrozen(true)
			end

			if customGravityEnabled and workspace.Gravity ~= gravityValue then
				workspace.Gravity = gravityValue
			end

			applyPlayerSettings()

			setHomeLabel("PlayerStateLabel", string.format(
				"Player: jump %s | freeze %s | gravity %.0f",
				customJumpEnabled and tostring(jumpPowerValue) or "default",
				stateText(freezeCharacterEnabled),
				workspace.Gravity
			))

			setHomeLabel("GraphicsStateLabel", string.format(
				"Graphics: shader %s | preset %s | map %.1fM",
				stateText(shaderEnabled),
				shaderPreset,
				minimapRange / 1000000
			))

			setHomeLabel("PlayerCountLabel", string.format(
				"Minimap: %d visible | %d tracked",
				minimapVisibleCount,
				minimapTrackedCount
			))
			setHomeLabel("NearestPlayerLabel", minimapNearestText)
		end
	end)

	UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.T then
			running = not running
			safeSetValue(teleportToggle, running)

			if running then
				startTeleport()
			else
				stopTeleport()
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			riotRunning = not riotRunning
			safeSetValue(riotToggle, riotRunning)

			if riotRunning then
				startRiot()
			else
				stopRiot()
			end
		end
	end)

	toast("Ascida loaded.")
end

local ok, err = pcall(loadMainUI)

if not ok then
	notify("Startup failed: " .. tostring(err))
	error(err)
end
