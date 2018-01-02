if select(2, UnitClass('player')) ~= 'HUNTER' then
	DisableAddOn('Shrapnel')
	return
end

-- useful functions
local function startsWith(str, start) -- case insensitive check to see if a string matches the start of another string
	if type(str) ~= 'string' then
		return false
	end
   return string.lower(str:sub(1, start:len())) == start:lower()
end
-- end useful functions

Shrapnel = {}

SLASH_Shrapnel1, SLASH_Shrapnel2 = '/shrapnel', '/shr'
BINDING_HEADER_SHRAPNEL = 'Shrapnel'

local function InitializeVariables()
	local function SetDefaults(t, ref)
		for k, v in next, ref do
			if t[k] == nil then
				local pchar
				if type(v) == 'boolean' then
					pchar = v and 'true' or 'false'
				elseif type(v) == 'table' then
					pchar = 'table'
				else
					pchar = v
				end
				t[k] = v
			elseif type(t[k]) == 'table' then
				SetDefaults(t[k], v)
			end
		end
	end
	SetDefaults(Shrapnel, { -- defaults
		locked = false,
		snap = false,
		scale = {
			main = 1,
			previous = 0.7,
			cooldown = 0.7,
			interrupt = 0.4,
			trap = 0.4,
			glow = 1,
		},
		glow = {
			main = true,
			cooldown = true,
			interrupt = false,
			trap = true,
			blizzard = false,
			color = { r = 1, g = 1, b = 1 }
		},
		hide = {
			bm = false,
			mm = false,
			sv = false
		},
		alpha = 1,
		frequency = 0.05,
		previous = true,
		always_on = false,
		cooldown = true,
		aoe = false,
		gcd = true,
		dimmer = true,
		miss_effect = true,
		boss_only = false,
		interrupt = true,
		trap = true,
		single_90 = false,
		auto_aoe = false,
		pot = false
	})
end

-- specialization constants
local SPEC = {
	NONE = 0,
	BEAST_MASTERY = 1,
	MARKSMANSHIP = 2,
	SURVIVAL = 3
}

local events, glows = {}, {}

local me, abilityTimer, currentSpec, targetMode, combatStartTime = 0, 0, 0, 0, 0

-- tier set equipped pieces count
local Tier = {
	T19P = 0,
	T20P = 0,
	T21P = 0
}

-- legendary item equipped
local ItemEquipped = {
	FrizzosFingertrap = false
}

local var = {
	gcd = 0
}

local targetModes = {
	[SPEC.NONE] = {
		{1, ''}
	},
	[SPEC.BEAST_MASTERY] = {
		{1, ''},
		{2, '2+'},
		{6, '6+'}
	},
	[SPEC.MARKSMANSHIP] = {
		{1, ''},
		{2, '2+'},
		{4, '4+'},
		{6, '6+'}
	},
	[SPEC.SURVIVAL] = {
		{1, ''},
		{2, '2+'},
		{6, '6+'}
	}
}

local shrapnelPanel = CreateFrame('Frame', 'shrapnelPanel', UIParent)
shrapnelPanel:SetPoint('CENTER', 0, -169)
shrapnelPanel:SetFrameStrata('BACKGROUND')
shrapnelPanel:SetSize(64, 64)
shrapnelPanel:SetMovable(true)
shrapnelPanel:Hide()
shrapnelPanel.icon = shrapnelPanel:CreateTexture(nil, 'BACKGROUND')
shrapnelPanel.icon:SetAllPoints(shrapnelPanel)
shrapnelPanel.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
shrapnelPanel.border = shrapnelPanel:CreateTexture(nil, 'BORDER')
shrapnelPanel.border:SetAllPoints(shrapnelPanel)
shrapnelPanel.border:SetTexture('Interface\\AddOns\\Shrapnel\\border.blp')
shrapnelPanel.border:Hide()
shrapnelPanel.gcd = CreateFrame('Cooldown', nil, shrapnelPanel, 'CooldownFrameTemplate')
shrapnelPanel.gcd:SetAllPoints(shrapnelPanel)
shrapnelPanel.dimmer = shrapnelPanel:CreateTexture(nil, 'OVERLAY')
shrapnelPanel.dimmer:SetAllPoints(shrapnelPanel)
shrapnelPanel.dimmer:SetTexture(0, 0, 0, 0.6)
shrapnelPanel.dimmer:Hide()
shrapnelPanel.targets = shrapnelPanel:CreateFontString(nil, 'OVERLAY')
shrapnelPanel.targets:SetFont('Fonts\\FRIZQT__.TTF', 12, 'OUTLINE')
shrapnelPanel.targets:SetPoint('BOTTOMRIGHT', shrapnelPanel, 'BOTTOMRIGHT', -1.5, 3)
shrapnelPanel.button = CreateFrame('Button', 'shrapnelPanelButton', shrapnelPanel)
shrapnelPanel.button:SetAllPoints(shrapnelPanel)
shrapnelPanel.button:RegisterForClicks('LeftButtonDown', 'RightButtonDown', 'MiddleButtonDown')
local shrapnelPreviousPanel = CreateFrame('Frame', 'shrapnelPreviousPanel', UIParent)
shrapnelPreviousPanel:SetPoint('BOTTOMRIGHT', shrapnelPanel, 'BOTTOMLEFT', -10, -5)
shrapnelPreviousPanel:SetFrameStrata('BACKGROUND')
shrapnelPreviousPanel:SetSize(64, 64)
shrapnelPreviousPanel:Hide()
shrapnelPreviousPanel:RegisterForDrag('LeftButton')
shrapnelPreviousPanel:SetScript('OnDragStart', shrapnelPreviousPanel.StartMoving)
shrapnelPreviousPanel:SetScript('OnDragStop', shrapnelPreviousPanel.StopMovingOrSizing)
shrapnelPreviousPanel:SetMovable(true)
shrapnelPreviousPanel.icon = shrapnelPreviousPanel:CreateTexture(nil, 'BACKGROUND')
shrapnelPreviousPanel.icon:SetAllPoints(shrapnelPreviousPanel)
shrapnelPreviousPanel.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
shrapnelPreviousPanel.border = shrapnelPreviousPanel:CreateTexture(nil, 'BORDER')
shrapnelPreviousPanel.border:SetAllPoints(shrapnelPreviousPanel)
shrapnelPreviousPanel.border:SetTexture('Interface\\AddOns\\Shrapnel\\border.blp')
local shrapnelCooldownPanel = CreateFrame('Frame', 'shrapnelCooldownPanel', UIParent)
shrapnelCooldownPanel:SetPoint('BOTTOMLEFT', shrapnelPanel, 'BOTTOMRIGHT', 10, -5)
shrapnelCooldownPanel:SetSize(64, 64)
shrapnelCooldownPanel:SetFrameStrata('BACKGROUND')
shrapnelCooldownPanel:Hide()
shrapnelCooldownPanel:RegisterForDrag('LeftButton')
shrapnelCooldownPanel:SetScript('OnDragStart', shrapnelCooldownPanel.StartMoving)
shrapnelCooldownPanel:SetScript('OnDragStop', shrapnelCooldownPanel.StopMovingOrSizing)
shrapnelCooldownPanel:SetMovable(true)
shrapnelCooldownPanel.icon = shrapnelCooldownPanel:CreateTexture(nil, 'BACKGROUND')
shrapnelCooldownPanel.icon:SetAllPoints(shrapnelCooldownPanel)
shrapnelCooldownPanel.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
shrapnelCooldownPanel.border = shrapnelCooldownPanel:CreateTexture(nil, 'BORDER')
shrapnelCooldownPanel.border:SetAllPoints(shrapnelCooldownPanel)
shrapnelCooldownPanel.border:SetTexture('Interface\\AddOns\\Shrapnel\\border.blp')
shrapnelCooldownPanel.cd = CreateFrame('Cooldown', nil, shrapnelCooldownPanel, 'CooldownFrameTemplate')
shrapnelCooldownPanel.cd:SetAllPoints(shrapnelCooldownPanel)
local shrapnelInterruptPanel = CreateFrame('Frame', 'shrapnelInterruptPanel', UIParent)
shrapnelInterruptPanel:SetPoint('TOPLEFT', shrapnelPanel, 'TOPRIGHT', 16, 25)
shrapnelInterruptPanel:SetFrameStrata('BACKGROUND')
shrapnelInterruptPanel:SetSize(64, 64)
shrapnelInterruptPanel:Hide()
shrapnelInterruptPanel:RegisterForDrag('LeftButton')
shrapnelInterruptPanel:SetScript('OnDragStart', shrapnelInterruptPanel.StartMoving)
shrapnelInterruptPanel:SetScript('OnDragStop', shrapnelInterruptPanel.StopMovingOrSizing)
shrapnelInterruptPanel:SetMovable(true)
shrapnelInterruptPanel.icon = shrapnelInterruptPanel:CreateTexture(nil, 'BACKGROUND')
shrapnelInterruptPanel.icon:SetAllPoints(shrapnelInterruptPanel)
shrapnelInterruptPanel.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
shrapnelInterruptPanel.border = shrapnelInterruptPanel:CreateTexture(nil, 'BORDER')
shrapnelInterruptPanel.border:SetAllPoints(shrapnelInterruptPanel)
shrapnelInterruptPanel.border:SetTexture('Interface\\AddOns\\Shrapnel\\border.blp')
shrapnelInterruptPanel.cast = CreateFrame('Cooldown', nil, shrapnelInterruptPanel, 'CooldownFrameTemplate')
shrapnelInterruptPanel.cast:SetAllPoints(shrapnelInterruptPanel)
local shrapnelTrapPanel = CreateFrame('Frame', 'shrapnelTrapPanel', UIParent)
shrapnelTrapPanel:SetPoint('TOPRIGHT', shrapnelPanel, 'TOPLEFT', -16, 25)
shrapnelTrapPanel:SetFrameStrata('BACKGROUND')
shrapnelTrapPanel:SetSize(64, 64)
shrapnelTrapPanel:Hide()
shrapnelTrapPanel:RegisterForDrag('LeftButton')
shrapnelTrapPanel:SetScript('OnDragStart', shrapnelTrapPanel.StartMoving)
shrapnelTrapPanel:SetScript('OnDragStop', shrapnelTrapPanel.StopMovingOrSizing)
shrapnelTrapPanel:SetMovable(true)
shrapnelTrapPanel.icon = shrapnelTrapPanel:CreateTexture(nil, 'BACKGROUND')
shrapnelTrapPanel.icon:SetAllPoints(shrapnelTrapPanel)
shrapnelTrapPanel.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
shrapnelTrapPanel.border = shrapnelTrapPanel:CreateTexture(nil, 'BORDER')
shrapnelTrapPanel.border:SetAllPoints(shrapnelTrapPanel)
shrapnelTrapPanel.border:SetTexture('Interface\\AddOns\\Shrapnel\\border.blp')
shrapnelTrapPanel.cast = CreateFrame('Cooldown', nil, shrapnelTrapPanel, 'CooldownFrameTemplate')
shrapnelTrapPanel.cast:SetAllPoints(shrapnelTrapPanel)

local Ability, abilities, abilityBySpellId = {}, {}, {}
Ability.__index = Ability

function Ability.add(spellId, buff, player, spellId2)
	local name, _, icon = GetSpellInfo(spellId)
	local ability = {
		spellId = spellId,
		spellId2 = spellId2 or 0,
		name = name,
		icon = icon,
		focus_cost = 0,
		cooldown_duration = 0,
		buff_duration = 0,
		tick_interval = 0,
		requires_charge = false,
		requires_pet = false,
		triggers_gcd = true,
		hasted_duration = false,
		known = IsPlayerSpell(spellId),
		auraTarget = buff == 'pet' and 'pet' or buff and 'player' or 'target',
		auraFilter = (buff and 'HELPFUL' or 'HARMFUL') .. (player and '|PLAYER' or '')
	}
	setmetatable(ability, Ability)
	abilities[#abilities + 1] = ability
	abilityBySpellId[spellId] = ability
	return ability
end

function Ability:ready(seconds)
	return self:cooldown() <= (seconds or 0)
end

function Ability:usable(seconds)
	if self.focus_cost > var.focus then
		return false
	end
	if self.requires_charge and self:charges() == 0 then
		return false
	end
	if self.requires_pet and (not UnitExists('pet') or UnitIsDead('pet')) then
		return false
	end
	return self:ready(seconds)
end

function Ability:remains()
	if self.buff_duration > 0 and self:casting() then
		return self:duration()
	end
	local _, id, expires
	for i = 1, 40 do
		_, _, _, _, _, _, expires, _, _, _, id = UnitAura(self.auraTarget, i, self.auraFilter)
		if not id then
			return 0
		end
		if id == self.spellId or id == self.spellId2 then
			return max(expires - var.time - var.cast_remains, 0)
		end
	end
	return 0
end

function Ability:refreshable()
	if self.buff_duration > 0 then
		return self:remains() < self:duration() * 0.3
	end
	return self:down()
end

function Ability:up(excludeCasting)
	if not excludeCasting and self.buff_duration > 0 and self:casting() then
		return true
	end
	local _, id, expires
	for i = 1, 40 do
		_, _, _, _, _, _, expires, _, _, _, id = UnitAura(self.auraTarget, i, self.auraFilter)
		if not id then
			return false
		end
		if id == self.spellId or id == self.spellId2 then
			return expires == 0 or expires - var.time > var.cast_remains
		end
	end
end

function Ability:down(excludeCasting)
	return not self:up(excludeCasting)
end

function Ability:cooldown()
	if self.cooldown_duration > 0 and self:casting() then
		return self.cooldown_duration
	end
	local start, duration = GetSpellCooldown(self.spellId)
	return start > 0 and max(0, (duration - (var.time - start)) - var.cast_remains) or 0
end

function Ability:stack()
	local _, id, expires, count
	for i = 1, 40 do
		_, _, _, count, _, _, expires, _, _, _, id = UnitAura(self.auraTarget, i, self.auraFilter)
		if not id then
			return 0
		end
		if id == self.spellId or id == self.spellId2 then
			return (expires == 0 or expires - var.time > var.cast_remains) and count or 0
		end
	end
	return 0
end

function Ability:cost()
	return self.focus_cost
end

function Ability:charges()
	return GetSpellCharges(self.spellId) or 0
end

function Ability:duration()
	return self.hasted_duration and (var.haste_factor * self.buff_duration) or self.buff_duration
end

function Ability:casting()
	return var.cast_name == self.name
end

function Ability:channeling()
	return UnitChannelInfo('player') == self.name
end

function Ability:castTime()
	local _, _, _, castTime = GetSpellInfo(self.spellId)
	return castTime / 1000
end

function Ability:castRegen()
	return var.regen * max(1, self:castTime())
end

function Ability:tickInterval()
	return self.tick_interval - (self.tick_interval * (UnitSpellHaste('player') / 100))
end

function Ability:previous()
	if self:casting() or self:channeling() then
		return true
	end
	return var.last_gcd == self or var.last_ability == self
end

function Ability:recordTargetsHit()
	if not self.first_hit_time then
		self.first_hit_time = var.time
		self.target_hit_count = 0
	end
	self.target_hit_count = self.target_hit_count + 1
	for i = 1, #targetModes[currentSpec] do
		if self.target_hit_count >= targetModes[currentSpec][i][1] and targetModes[currentSpec][i][1] > targetModes[currentSpec][targetMode][1] then
			Shrapnel_SetTargetMode(i)
		end
	end
end

function Ability:updateTargetsHit()
	if self.first_hit_time and var.time - self.first_hit_time >= 0.3 then
		self.first_hit_time = nil
		local highestTargetMode = 1
		for i = 1, #targetModes[currentSpec] do
			if self.target_hit_count >= targetModes[currentSpec][i][1] and targetModes[currentSpec][i][1] > highestTargetMode then
				highestTargetMode = i
			end
		end
		if highestTargetMode ~= targetMode then
			Shrapnel_SetTargetMode(highestTargetMode)
		end
	end
end

-- Hunter Abilities
---- All specializations
local EagleEye = Ability.add(6197, true, true) -- used for GCD
---- Beast Mastery
local AMurderOfCrowsBM = Ability.add(131894, false, true)
local AspectOfTheWild = Ability.add(193530, true, true)
local BeastCleave = Ability.add(118455, 'pet', true)
local BestialWrath = Ability.add(19574, true, true)
local ChimaeraShot = Ability.add(53209, false, true)
local CobraShot = Ability.add(193455, false, true)
local CounterShot = Ability.add(147362, false, true)
local DireBeast = Ability.add(120679, false, true)
local DireFrenzy = Ability.add(217200, false, true)
local KillCommand = Ability.add(34026, false, true)
local MultiShot = Ability.add(2643, false, true)
local Stampede = Ability.add(201430, false, true)
local TitansThunder = Ability.add(208068, 'pet', true)
---- MM + BM talents
local Barrage = Ability.add(120360, true, true)
Barrage.focus_cost = 60
local Volley = Ability.add(194386, true, true)
---- Marksmanship
local AMurderOfCrowsMM = Ability.add(131894, false, true)
AMurderOfCrowsMM.focus_cost = 30
AMurderOfCrowsMM.cooldown_duration = 60
local AimedShot = Ability.add(19434, false, true)
AimedShot.focus_cost = 50
local ArcaneShot = Ability.add(185358, false, true)
ArcaneShot.focus_cost = -8
local BlackArrow = Ability.add(194599, false, true)
local Bullseye = Ability.add(204090, true, true)
local BurstingShot = Ability.add(186387, false, true)
local ExplosiveShot = Ability.add(212431, false, true)
ExplosiveShot.focus_cost = 20
local HuntersMark = Ability.add(185987, false, true, 185365)
local LockAndLoad = Ability.add(194595, true, true, 194594)
local MarkedShot = Ability.add(185901, false, true)
MarkedShot.focus_cost = 25
local MarkingTargets = Ability.add(223138, true, true)
local PatientSniper = Ability.add(234588, false, true)
local PiercingShot = Ability.add(198670, false, true)
PiercingShot.focus_cost = 20
local Sentinel = Ability.add(206817, true, true)
local SentinelsSight = Ability.add(208913, true, true)
local Sidewinders = Ability.add(214579, false, true)
Sidewinders.requires_charge = true
local TrickShot = Ability.add(199522, true, true)
local Trueshot = Ability.add(193526, true, true)
local Vulnerable = Ability.add(187131, false, true)
local Windburst = Ability.add(204147, false, true)
Windburst.focus_cost = 20
Windburst.cooldown_duration = 8
---- Survival
local AMurderOfCrowsSV = Ability.add(206505, false, true)
AMurderOfCrowsSV.focus_cost = 30
AMurderOfCrowsSV.buff_duration = 15
local AspectOfTheEagle = Ability.add(186289, true, true)
AspectOfTheEagle.buff_duration = 10
local Butchery = Ability.add(212436, false, true)
Butchery.focus_cost = 40
Butchery.requires_charge = true
local Caltrops = Ability.add(194277, false, true, 194279)
Caltrops.buff_duration = 6
local Carve = Ability.add(187708, false, true)
local DragonsfireGrenade = Ability.add(194855, false, true, 194858)
DragonsfireGrenade.buff_duration = 8
local ExplosiveTrap = Ability.add(191433, false, true, 13812)
ExplosiveTrap.buff_duration = 10
local FlankingStrike = Ability.add(202800, false, true)
FlankingStrike.focus_cost = 50
FlankingStrike.requires_pet = true
local FuryOfTheEagle = Ability.add(203415, false, true)
local Harpoon = Ability.add(190925, false, true, 190927)
local OnTheTrail = Ability.add(204081, false, true)
local Lacerate = Ability.add(185855, false, true)
Lacerate.focus_cost = 45
Lacerate.buff_duration = 12
local MongooseBite = Ability.add(190928, true, true, 190931)
MongooseBite.requires_charge = true
local MongooseFury = MongooseBite
MongooseFury.buff_duration = 14
local Muzzle = Ability.add(187707, false, true)
local RaptorStrike = Ability.add(186270, false, true)
RaptorStrike.focus_cost = 25
local SerpentSting = Ability.add(87935, false, true, 118253)
SerpentSting.buff_duration = 15
local SnakeHunter = Ability.add(201078, true, true)
local SpittingCobra = Ability.add(194407, true, true)
SpittingCobra.buff_duration = 30
local SteelTrap = Ability.add(162488, false, true, 162487)
SteelTrap.buff_duration = 30
local ThrowingAxes = Ability.add(200163, false, true)
ThrowingAxes.focus_cost = 15
local WaysOfTheMokNathal = Ability.add(201082, true, true, 201081)
WaysOfTheMokNathal.buff_duration = 12
local MokNathalTactics = WaysOfTheMokNathal

-- Tier Bonuses
local T19Survival4P = Ability.add(211357, true, true, 211362)
-- Racials
local ArcaneTorrent = Ability.add(80483, true, false) -- Blood Elf
ArcaneTorrent.focus_cost = -15
ArcaneTorrent.triggers_gcd = false
-- Potions
local ProlongedPower = Ability.add(229206, true, true)
-- Trinkets

local Target = {
	boss = false,
	guid = 0,
	healthArray = {},
	hostile = false
}

local function GetAbilityCasting()
	if not var.cast_name then
		return
	end
	for i = 1,#abilities do
		if abilities[i].name == var.cast_name then
			return abilities[i]
		end
	end
end

local function GetCastRegen()
	return var.regen * var.cast_remains - (var.cast_ability and var.cast_ability.focus_cost or 0)
end

local function UpdateVars()
	local _, start, duration, remains, hp
	var.last_main = var.main
	var.last_cd = var.cd
	var.last_trap = var.trap
	var.time = GetTime()
	var.gcd = 1.5 - (1.5 * (UnitSpellHaste('player') / 100))
	start, duration = GetSpellCooldown(EagleEye.spellId)
	var.gcd_remains = start > 0 and duration - (var.time - start) or 0
	var.cast_name, _, _, _, _, remains = UnitCastingInfo('player')
	var.cast_remains = remains and remains / 1000 - var.time or var.gcd_remains
	var.cast_ability = GetAbilityCasting()
	var.haste_factor = 1 / (1 + UnitSpellHaste('player') / 100)
	var.regen = GetPowerRegen()
	var.focus_regen = GetCastRegen()
	var.focus_max = UnitPowerMax('player')
	var.focus = min(var.focus_max, floor(UnitPower('player') + var.focus_regen))
	Target.healthArray[#Target.healthArray + 1] = UnitHealth('target')
	table.remove(Target.healthArray, 1)
	Target.healthPercentage = Target.guid == 0 and 100 or UnitHealth('target') / UnitHealthMax('target') * 100
	hp = Target.healthArray[1] - Target.healthArray[#Target.healthArray]
	Target.timeToDie = hp > 0 and Target.healthArray[#Target.healthArray] / (hp / 3) or 600
end

local function Focus()
	return var.focus
end

local function FocusDeficit()
	return var.focus_max - var.focus
end

local function FocusRegen()
	return var.focus_regen
end

local function FocusMax()
	return var.focus_max
end

local function HasteFactor()
	return var.haste_factor
end

local function GCD()
	return var.gcd
end

local function GCDRemains()
	return var.gcd_remains
end

local function PlayerIsMoving()
	return GetUnitSpeed('player') ~= 0
end

local function Enemies()
	return targetModes[currentSpec][targetMode][1]
end

local function TimeInCombat()
	return combatStartTime > 0 and var.time - combatStartTime or 0
end

function ProlongedPower:cooldown()
	local startTime, duration = GetItemCooldown(142117)
	return duration - (var.time - startTime)
end

local function BloodlustActive()
	local _, id
	for i = 1, 40 do
		_, _, _, _, _, _, _, _, _, _, id = UnitAura('player', i, 'HELPFUL')
		if id == 2825 or id == 32182 or id == 80353 or id == 90355 or id == 160452 or id == 146555 then
			return true
		end
	end
end

local function UseCooldown(ability, overwrite, always)
	if always or (Shrapnel.cooldown and (not Shrapnel.boss_only or Target.boss) and (not var.cd or overwrite)) then
		var.cd = ability
	end
end

local function UseTrap(ability, overwrite)
	if Shrapnel.trap and (not var.trap or overwrite) then
		var.trap = ability
	end
end

local function DetermineAbilityBeastMastery()
--[[
	if UseCooldown() then
		if Shrapnel.pot and Target.boss and DraenicAgility:ready() and (((FocusFire:up() or BloodlustActive()) and Stampede:ready(1)) or Target.timeToDie < 25) then
			ability.cd = DraenicAgility
		elseif Stampede.known and Target.boss and Stampede:ready() and (FocusFire:up() or BloodlustActive() or Target.timeToDie < 25) then
			ability.cd = Stampede
		end
	end
	if Frenzy:stack() > 0 and Frenzy:remains() < 2 then
		return FocusFire
	elseif DireBeast.known and DireBeast:ready() then
		return DireBeast
	elseif Frenzy:stack() > 0 and FocusFire:down() and ((BestialWrath:ready(1) and BestialWrath:down()) or (Stampede.known and Stampede:cooldown() > 260)) then
		return FocusFire
	end
	if UseCooldown() and BestialWrath:ready() and Focus() > 30 and BestialWrath:down() then
		ability.cd = BestialWrath
	end
	if Enemies() > 1 and MultiShot:usable() and BeastCleave:remains() < 0.5 then
		return MultiShot
	elseif Frenzy:stack() >= 5 and FocusFire:down() then
		return FocusFire
	elseif Barrage.known and Enemies() > 1 and Barrage:ready() and Barrage:usable() then
		return Barrage
	elseif Enemies() > 5 and ExplosiveTrap:ready() then
		return ExplosiveTrap
	elseif Enemies() > 5 and MultiShot:usable() then
		return MultiShot
	elseif KillCommand:ready() and KillCommand:usable() then
		return KillCommand
	end
	if UseCooldown() and AMurderOfCrows.known and AMurderOfCrows:ready() and AMurderOfCrows:usable() then
		ability.cd = AMurderOfCrows
	end
	if KillShot:ready() and KillShot:usable() and KillShot:castRegen() < FocusDeficit() then
		return KillShot
	elseif FocusingShot.known and Focus() < 50 then
		return FocusingShot
	elseif SteadyFocus.known and not FocusingShot.known and SteadyFocus:pre() and SteadyFocus:remains() < 7 and CobraShot:castRegen() + 14 < FocusDeficit() then
		return CobraShot
	elseif Enemies() > 1 and ExplosiveTrap:ready() then
		return ExplosiveTrap
	elseif SteadyFocus.known and not (FocusingShot.known or CobraShot:casting()) and Focus() < 50 and SteadyFocus:remains() < 4 then
		return CobraShot
	elseif GlaiveToss.known and (Shrapnel.single_90 or Enemies() > 1) and GlaiveToss:ready() and GlaiveToss:usable() then
		return GlaiveToss
	elseif Barrage.known and Shrapnel.single_90 and Barrage:ready() and Barrage:usable() then
		return Barrage
	elseif Enemies() > 5 then
		return CobraShot
	elseif ArcaneShot:usable() and ((Focus() > (ThrillOfTheHunt:up() and 35 or 75)) or BestialWrath:up()) then
		return ArcaneShot
	else
		return CobraShot
	end
]]
end

--[[
local MM_Var = {
	TrueshotCooldown = 0,
	PoolingForPiercing = false,
	WaitingForSentinel = false,
	VulnWindow = 0,
	VulnAimCasts = 0,
	CanGCD = false
}

local function APL_MM_NonPatientSniper()
	return
end

local function APL_MM_PatientSniper()
	MM_Var.VulnWindow = Vulnerable:remains()
	--if Sidewinders.known and 
	MM_Var.VulnAimCasts = floor(MM_Var.VulnWindow % AimedShot:castTime())
	if MM_Var.VulnAimCasts > 0 and MM_Var.VulnAimCasts > floor((AimedShot:castRegen() * (MM_Var.VulnAimCasts - 1)) % AimedShot:cost()) then
		MM_Var.VulnAimCasts = floor((Focus() + AimedShot:castRegen() * (MM_Var.VulnAimCasts - 1)) % AimedShot:cost())
	end
	MM_Var.CanGCD = MM_Var.VulnWindow > MM_Var.VulnAimCasts * AimedShot:castTime() + GCD()
	if PiercingShot.known and PiercingShot:usable() then
		if Enemies() == 1 and Vulnerable:up() and Vulnerable:remains() < 1 then
			return PiercingShot
		end
		if Enemies() > 1 and Vulnerable:up() and ((Trueshot:down() and Focus() > 80 and (Vulnerable:remains() < 1 or HuntersMark:up())) or (Trueshot:up() and Focus() > 105 and Vulnerable:remains() < 6)) then
			return PiercingShot
		end
	end
	if Enemies() > 1 then
		if TrickShot.known and AimedShot:usable() and Vulnerable:remains() > AimedShot:castTime() and (SentinelsSight:stack() == 20 or (Trueshot:up() and SentinelsSight:stack() >= Enemies() * 5)) then
			return AimedShot
		end
		if MarkedShot:usable() and HuntersMark:up() and not MarkedShot:casting() then
			return MarkedShot
		end
		if not Sidewinders.known and MultiShot:usable() and (MarkingTargets:up() or Trueshot:up()) then
			return MultiShot
		end
	end
	if Windburst:usable() and MM_Var.VulnAimCasts < 1 and not MM_Var.PoolingForPiercing then
		return Windburst
	end
	if BlackArrow.known and BlackArrow:usable() and MM_Var.CanGCD and (Sidewinders.known or Enemies() < 6) and (not MM_Var.PoolingForPiercing or Vulnerable:remains() > GCD()) and (Enemies() < 4 or TrickShot.known) then
		return BlackArrow
	end
	if AMurderOfCrowsMM.known and AMurderOfCrowsMM:usable() and (not MM_Var.PoolingForPiercing or Vulnerable:remains() > GCD()) and (Target.timeToDie >= AMurderOfCrowsMM:cooldown() + 15 or Target.healthPercentage < 20 or Target.timeToDie < 16) then
		return AMurderOfCrowsMM
	end
	if Barrage.known and Barrage:usable() and (Enemies() > 2 or (Target.healthPercentage < 20 and Bullseye:stack() < 25)) then
		return Barrage
	end
	if LockAndLoad.known and AimedShot:usable() and Vulnerable:up() and LockAndLoad:up() and (not MM_Var.PoolingForPiercing or Vulnerable:remains() > GCD()) and (Enemies() < 4 or TrickShot.known) then
		return AimedShot
	end
	if AimedShot:usable() and Enemies() > 1 and Vulnerable:remains() > AimedShot:castTime() and (not MM_Var.PoolingForPiercing or (Focus() > 100 and Vulnerable:remains() > (AimedShot:castTime() + GCD()))) and (Enemies() < 4 or SentinelsSight:stack() == 20 or TrickShot.known) then
		return AimedShot
	end
	if not Sidewinders.known then
		if Enemies() > 1 and MM_Var.CanGCD and (Focus() + (Enemies() * 3) + AimedShot:castRegen()) < FocusMax() and (not MM_Var.PoolingForPiercing or Vulnerable:remains() > GCD()) then
			return MultiShot
		end
		if Enemies() == 1 and MM_Var.VulnAimCasts > 0 and MM_Var.CanGCD and (Focus() + 8 + AimedShot:castRegen()) < FocusMax() and (not MM_Var.PoolingForPiercing or Vulnerable:remains() > GCD()) then
			return ArcaneShot
		end
	end
	if AimedShot:usable() then
		if Sidewinders.known and Vulnerable:remains() > AimedShot:castTime() and (MM_Var.VulnWindow - (AimedShot:castTime() * MM_Var.VulnAimCasts) < 1 or FocusDeficit() < 25 or Trueshot:up()) and (Enemies() == 1 or Focus() > 100) then
			return AimedShot
		end
		if not Sidewinders.known and Vulnerable:remains() > AimedShot:castTime() and (not MM_Var.PoolingForPiercing or (Focus() > 100 and Vulnerable:remains() > (AimedShot:castTime() + GCD()))) then
			return AimedShot
		end
	end
	if MarkedShot:usable() and HuntersMark:up() and not MarkedShot:casting() then
		if Sidewinders.known and (MM_Var.VulnAimCasts < 1 or Trueshot:up() or MM_Var.VulnWindow < AimedShot:castTime()) then
			return MarkedShot
		end
		if not Sidewinders.known and not MM_Var.PoolingForPiercing then
			return MarkedShot
		end
	end
	if AimedShot:usable() and Enemies() == 1 and Focus() > 110 then
		return AimedShot
	end
	if Sidewinders.known then
		if Sidewinders:usable() and (HuntersMark:down() or (MarkingTargets:down() and Trueshot:down())) and ((MarkingTargets:up() and MM_Var.VulnAimCasts < 1) or Trueshot:up() or Sidewinders:charges() >= 2) then
			return Sidewinders
		end
	else
		if not MM_Var.PoolingForPiercing or Vulnerable:remains() > GCD() then
			return Enemies() == 1 and ArcaneShot or MultiShot
		end
	end
end

local function APL_MM_TargetDie()
	if PiercingShot.known and PiercingShot:usable() and Vulnerable:up() and not PiercingShot:casting() then
		return PiercingShot
	end
	if ExplosiveShot.known and ExplosiveShot:usable() then
		return ExplosiveShot
	end
	if Windburst:usable() then
		return Windburst
	end
	if LockAndLoad.known and AimedShot:usable() and Vulnerable:up() and LockAndLoad:up() then
		return AimedShot
	end
	if MarkedShot:usable() and HuntersMark:up() and not MarkedShot:casting() then
		return MarkedShot
	end
	if not Sidewinders.known and MarkingTargets:up() or Trueshot:up() then
		return ArcaneShot
	end
	if AimedShot:usable() and Vulnerable:remains() > AimedShot:castTime() and Target.timeToDie > AimedShot:castTime() then
		return AimedShot
	end
	if Sidewinders.known then
		if Sidewinders:usable() then
			return Sidewinders
		end
	else
		return ArcaneShot
	end
end
]]

local function DetermineAbilityMarksmanship()
--[[
	--if UseCooldown() and Volley.known and Volley:down() then
	--	ability.cd = Volley
	--end
	MM_Var.PoolingForPiercing = PiercingShot.known and PiercingShot:cooldown() < 5 and Vulnerable:up() and Vulnerable:remains() > PiercingShot:cooldown() and (Trueshot:down() or Enemies() == 1)
	MM_Var.WaitingForSentinel = Sentinel.known and (MarkingTargets:up() or Trueshot:up()) and not Sentinel:ready() and ((Sentinel:cooldown() > 54 and Sentinel:cooldown() < (54 + GCD())) or (Sentinel:cooldown() > 48 and Sentinel:cooldown() < (48 + GCD())) or (Sentinel:cooldown() > 42 and Sentinel:cooldown() < (42 + GCD())))
	if TimeInCombat() > 15 and Trueshot:ready() and MM_Var.TrueshotCooldown == 0 then
		MM_Var.TrueshotCooldown = TimeInCombat() * 1.1
	end
	if Trueshot:ready() and (MM_Var.TrueshotCooldown == 0 or BloodlustActive() or (MM_Var.TrueshotCooldown > 0 and Target.timeToDie > (MM_Var.TrueshotCooldown + 15)) or Bullseye:stack() > 25 or Target.timeToDie < 16) then
		UseCooldown(Trueshot)
	end
	if Enemies() == 1 and Target.timeToDie < 6 then
		return APL_MM_TargetDie()
	end
	if PatientSniper.known then
		return APL_MM_PatientSniper()
	end
	return APL_MM_NonPatientSniper()
]]
end

local function DetermineAbilitySurvivalMokNathal()
	if T19Survival4P.known and MongooseBite:usable() and MongooseFury:stack() == 5 and MongooseFury:remains() < (GCD() + 0.4) then
		return MongooseBite
	end
	if MokNathalTactics:up() and MokNathalTactics:remains() < (GCD() + 0.4) then
		return RaptorStrike
	end
	if MongooseBite:usable() and (MongooseFury:stack() == 6 or (MongooseFury:stack() >= 4 and MongooseBite:charges() == 3)) then
		return MongooseBite
	end
	if RaptorStrike:usable() and MokNathalTactics:stack() <= 1 then
		return RaptorStrike
	end
	if FuryOfTheEagle:ready() and MongooseFury:remains() < (GCD() + 0.4) and MongooseFury:stack() >= 4 and MokNathalTactics:remains() > 4 then
		return FuryOfTheEagle
	end
	if SnakeHunter.known and SnakeHunter:ready() and MongooseBite:charges() == 0 and MongooseFury:remains() > 3 * GCD() and TimeInCombat() > 15 then
		UseCooldown(SnakeHunter)
	end
	if SpittingCobra.known and SpittingCobra:ready() and MongooseFury:remains() >= GCD() and MongooseFury:stack() < 4 and MokNathalTactics:stack() >= 3 then
		UseCooldown(SpittingCobra)
	end
	if SteelTrap.known and SteelTrap:ready() and Target.timeToDie > 6 and MongooseFury:down() then
		UseTrap(SteelTrap)
	end
	if AMurderOfCrowsSV.known and AMurderOfCrowsSV:ready() and Target.timeToDie > 6 and Focus() > (55 - MokNathalTactics:remains() * FocusRegen()) and MongooseFury:stack() < 4 and MongooseFury:remains() >= GCD() then
		return AMurderOfCrowsSV
	end
	if FlankingStrike:usable() and MongooseBite:charges() <= 1 and Focus() > (75 - MokNathalTactics:remains() * FocusRegen()) then
		return FlankingStrike
	end
	if ItemEquipped.FrizzosFingertrap and Lacerate:up() and Lacerate:refreshable() and Focus() > (65 - MokNathalTactics:remains() * FocusRegen()) and MongooseFury:remains() >= GCD() then
		if Butchery.known then
			if Butchery:usable() then
				return Butchery
			end
		else
			if Carve:usable() then
				return Carve
			end
		end
	end
	if Lacerate:usable() and Lacerate:refreshable() and Target.timeToDie > Lacerate:remains() + 6 then
		if Focus() > (55 - MokNathalTactics:remains() * FocusRegen()) and MongooseFury:remains() >= GCD() and MongooseBite:charges() == 0 and MongooseFury:stack() < 3 then
			return Lacerate
		end
		if Focus() > (65 - MokNathalTactics:remains() * FocusRegen()) and MongooseFury:down() and MongooseBite:charges() < 3 then
			return Lacerate
		end
	end
	if Caltrops.known and Caltrops:ready() and (Enemies() > 1 or Target.timeToDie > 8) and Caltrops:down() and MongooseFury:down() then
		UseTrap(Caltrops)
	end
	if ExplosiveTrap:ready() and (Enemies() > 1 or Target.timeToDie > 4) and MongooseFury:down() and MongooseBite:charges() == 0 then
		UseTrap(ExplosiveTrap)
	end
	if Enemies() > 1 and Focus() > (65 - MokNathalTactics:remains() * FocusRegen()) then
		if Butchery.known then
			if Butchery:usable() and (MongooseFury:down() or MongooseFury:remains() > (GCD() * MongooseBite:charges())) then
				return Butchery
			end
		else
			if Carve:usable() and (MongooseFury:down() or (MongooseFury:remains() > (GCD() * MongooseBite:charges()) and Focus() > (70 - MokNathalTactics:remains() * FocusRegen()))) then
				return Carve
			end
		end
	end
	if RaptorStrike:usable() and MokNathalTactics:stack() == 2 then
		return RaptorStrike
	end
	if DragonsfireGrenade.known and DragonsfireGrenade:ready() and MongooseFury:down() then
		UseTrap(DragonsfireGrenade)
	end
	if FuryOfTheEagle:ready() and MokNathalTactics:remains() > 4 and MongooseFury:stack() == 6 then
		return FuryOfTheEagle
	end
	if MongooseBite:usable() and AspectOfTheEagle:up() and MongooseFury:up() and MokNathalTactics:stack() >= 4 then
		return MongooseBite
	end
	if MokNathalTactics:remains() < 4 and MongooseFury:stack() == 6 and MongooseFury:remains() > FuryOfTheEagle:cooldown() and FuryOfTheEagle:cooldown() <= 5 then
		return RaptorStrike
	end
	if MongooseFury:up() and MongooseFury:remains() <= (3 * GCD()) and MokNathalTactics:remains() < (4 + GCD()) and FuryOfTheEagle:cooldown() < GCD() then
		return RaptorStrike
	end
	if AspectOfTheEagle:ready() and ((MongooseFury:stack() > 4 and TimeInCombat() < 15) or (MongooseFury:stack() > 1 and TimeInCombat() > 15) or (MongooseFury:remains() > 6 and MongooseBite:charges() < 2)) then
		UseCooldown(AspectOfTheEagle)
	end
	if MongooseBite:usable() and MongooseFury:up() and MongooseFury:remains() < AspectOfTheEagle:cooldown() then
		return MongooseBite
	end
	if SpittingCobra.known and SpittingCobra:ready() then
		UseCooldown(SpittingCobra)
	end
	if SteelTrap.known and SteelTrap:ready() and Target.timeToDie > 6 then
		UseTrap(SteelTrap)
	end
	if AMurderOfCrowsSV.known and AMurderOfCrowsSV:usable() and Target.timeToDie > 6 and Focus() > (55 - MokNathalTactics:remains() * FocusRegen()) then
		return AMurderOfCrowsSV
	end
	if Caltrops.known and Caltrops:ready() and Caltrops:down() and (Enemies() > 1 or Target.timeToDie > 8) then
		UseTrap(Caltrops)
	elseif ExplosiveTrap:ready() and (Enemies() > 1 or Target.timeToDie > 4) then
		UseTrap(ExplosiveTrap)
	end
	if ItemEquipped.FrizzosFingertrap and Lacerate:up() and Lacerate:refreshable() and Focus() > (65 - MokNathalTactics:remains() * FocusRegen()) then
		if Butchery.known then
			if Butchery:usable() then
				return Butchery
			end
		else
			if Carve:usable() then
				return Carve
			end
		end
	end
	if Lacerate:usable() and Lacerate:refreshable() and Target.timeToDie > Lacerate:remains() + 6 and Focus() > (55 - MokNathalTactics:remains() * FocusRegen()) then
		return Lacerate
	end
	if DragonsfireGrenade.known and DragonsfireGrenade:ready() then
		UseTrap(DragonsfireGrenade)
	end
	if MongooseBite:ready() and (MongooseBite:charges() >= 3 or (MongooseBite:charges() == 2 and MongooseBite:cooldown() <= GCD())) then
		return MongooseBite
	end
	if FlankingStrike:usable() then
		return FlankingStrike
	end
	if OnTheTrail:down() and Harpoon:ready() then
		UseCooldown(Harpoon)
	end
	if Butchery.known and Butchery:usable() and (Enemies() > 1 or Shrapnel.single_90) and (Focus() > (65 - MokNathalTactics:remains() * FocusRegen()) or (Enemies() == 1 and Target.timeToDie < 2)) then
		return Butchery
	end
	if RaptorStrike:usable() and (Focus() > (75 - FlankingStrike:cooldown() * FocusRegen()) or (Enemies() == 1 and Target.timeToDie < 2)) then
		return RaptorStrike
	end
end

local function DetermineAbilitySurvival()
	if TimeInCombat() == 0 and OnTheTrail:down() and Harpoon:ready() then
		UseCooldown(Harpoon)
	end
	return DetermineAbilitySurvivalMokNathal()
end

local function DetermineAbility()
	var.cd = nil
	var.interrupt = nil
	var.trap = nil
	if currentSpec == SPEC.BEAST_MASTERY then
		return DetermineAbilityBeastMastery()
	elseif currentSpec == SPEC.MARKSMANSHIP then
		return DetermineAbilityMarksmanship()
	elseif currentSpec == SPEC.SURVIVAL then
		return DetermineAbilitySurvival()
	end
	shrapnelPreviousPanel:Hide()
end

local function DetermineInterrupt()
	if CounterShot.known and CounterShot:ready() then
		return CounterShot
	end
	if Muzzle.known and Muzzle:ready() then
		return Muzzle
	end
	if ArcaneTorrent.known and ArcaneTorrent:ready() then
		return ArcaneTorrent
	end
end

local function UpdateInterrupt()
	local _, _, _, _, start, ends, _, _, notInterruptible = UnitCastingInfo('target')
	if not start or notInterruptible then
		var.interrupt = nil
		shrapnelInterruptPanel:Hide()
		return
	end
	var.interrupt = DetermineInterrupt()
	if var.interrupt then
		shrapnelInterruptPanel.icon:SetTexture(var.interrupt.icon)
		shrapnelInterruptPanel.icon:Show()
		shrapnelInterruptPanel.border:Show()
	else
		shrapnelInterruptPanel.icon:Hide()
		shrapnelInterruptPanel.border:Hide()
	end
	shrapnelInterruptPanel:Show()
	shrapnelInterruptPanel.cast:SetCooldown(start / 1000, (ends - start) / 1000)
end

local function DenyOverlayGlow(actionButton)
	if not Shrapnel.glow.blizzard then
		actionButton.overlay:Hide()
	end
end

hooksecurefunc('ActionButton_ShowOverlayGlow', DenyOverlayGlow) -- Disable Blizzard's built-in action button glowing

local function UpdateGlowColorAndScale()
	local w, h, glow
	local r = Shrapnel.glow.color.r
	local g = Shrapnel.glow.color.g
	local b = Shrapnel.glow.color.b
	for i = 1, #glows do
		glow = glows[i]
		w, h = glow.button:GetSize()
		glow:SetSize(w * 1.4, h * 1.4)
		glow:SetPoint('TOPLEFT', glow.button, 'TOPLEFT', -w * 0.2 * Shrapnel.scale.glow, h * 0.2 * Shrapnel.scale.glow)
		glow:SetPoint('BOTTOMRIGHT', glow.button, 'BOTTOMRIGHT', w * 0.2 * Shrapnel.scale.glow, -h * 0.2 * Shrapnel.scale.glow)
		glow.spark:SetVertexColor(r, g, b)
		glow.innerGlow:SetVertexColor(r, g, b)
		glow.innerGlowOver:SetVertexColor(r, g, b)
		glow.outerGlow:SetVertexColor(r, g, b)
		glow.outerGlowOver:SetVertexColor(r, g, b)
		glow.ants:SetVertexColor(r, g, b)
	end
end

local function CreateOverlayGlows()
	local GenerateGlow = function(button)
		if button then
			local glow = CreateFrame('Frame', nil, button, 'ActionBarButtonSpellActivationAlert')
			glow:Hide()
			glow.button = button
			glows[#glows + 1] = glow
		end
	end
	if Bartender4 then
		for i = 1, 120 do
			GenerateGlow(_G['BT4Button' .. i])
		end
	elseif ElvUI then
		for b = 1, 6 do
			for i = 1, 12 do
				GenerateGlow(_G['ElvUI_Bar' .. b .. 'Button' .. i])
			end
		end
	else
		for i = 1, 12 do
			GenerateGlow(_G['ActionButton' .. i])
			GenerateGlow(_G['MultiBarLeftButton' .. i])
			GenerateGlow(_G['MultiBarRightButton' .. i])
			GenerateGlow(_G['MultiBarBottomLeftButton' .. i])
			GenerateGlow(_G['MultiBarBottomRightButton' .. i])
		end
		if Dominos then
			for i = 1, 60 do
				GenerateGlow(_G['DominosActionButton' .. i])
			end
		end
	end
	UpdateGlowColorAndScale()
end

local function UpdateGlows()
	local glow, icon
	for i = 1, #glows do
		glow = glows[i]
		icon = glow.button.icon:GetTexture()
		if icon and glow.button.icon:IsVisible() and (
			(Shrapnel.glow.main and var.main and icon == var.main.icon) or
			(Shrapnel.glow.cooldown and var.cd and icon == var.cd.icon) or
			(Shrapnel.glow.interrupt and var.interrupt and icon == var.interrupt.icon) or
			(Shrapnel.glow.trap and var.trap and icon == var.trap.icon)
			) then
			if not glow:IsVisible() then
				glow.animIn:Play()
			end
		elseif glow:IsVisible() then
			glow.animIn:Stop()
			glow:Hide()
		end
	end
end

function events:ACTIONBAR_SLOT_CHANGED()
	UpdateGlows()
end

function events:PLAYER_LOGIN()
	me = UnitGUID('player')
	CreateOverlayGlows()
	if Shrapnel.snap then
		shrapnelPanel:ClearAllPoints()
		shrapnelPanel:SetPoint('CENTER', 0, -169)
	end
end

local function ShouldHide()
	return (currentSpec == SPEC.NONE or
		   (currentSpec == SPEC.BEAST_MASTERY and Shrapnel.hide.bm) or
		   (currentSpec == SPEC.MARKSMANSHIP and Shrapnel.hide.mm) or
		   (currentSpec == SPEC.SURVIVAL and Shrapnel.hide.sv))
end

local function Disappear()
	var.main = nil
	var.cd = nil
	var.interrupt = nil
	var.trap = nil
	UpdateGlows()
	shrapnelPanel:Hide()
	shrapnelPanel.border:Hide()
	shrapnelPreviousPanel:Hide()
	shrapnelCooldownPanel:Hide()
	shrapnelInterruptPanel:Hide()
	shrapnelTrapPanel:Hide()
end

function Shrapnel_ToggleTargetMode()
	local mode = targetMode + 1
	Shrapnel_SetTargetMode(mode > #targetModes[currentSpec] and 1 or mode)
end

function Shrapnel_ToggleTargetModeReverse()
	local mode = targetMode - 1
	Shrapnel_SetTargetMode(mode < 1 and #targetModes[currentSpec] or mode)
end

function Shrapnel_SetTargetMode(mode)
	targetMode = min(mode, #targetModes[currentSpec])
	shrapnelPanel.targets:SetText(targetModes[currentSpec][targetMode][2])
end

function Equipped(name, slot)
	local function SlotMatches(name, slot)
		local ilink = GetInventoryItemLink('player', slot)
		if ilink then
			local iname = ilink:match('%[(.*)%]')
			return (iname and iname:find(name))
		end
		return false
	end
	if slot then
		return SlotMatches(name, slot)
	end
	for slot = 1, 19 do
		if SlotMatches(name, slot) then
			return true
		end
	end
	return false
end

function EquippedTier(name)
	local slot = { 1, 3, 5, 7, 10, 15 }
	local equipped = 0
	for i = 1, #slot do
		if Equipped(name, slot) then
			equipped = equipped + 1
		end
	end
	return equipped
end

local function UpdateDraggable()
	shrapnelPanel:EnableMouse(Shrapnel.aoe or not Shrapnel.locked)
	if Shrapnel.aoe then
		shrapnelPanel.button:Show()
	else
		shrapnelPanel.button:Hide()
	end
	if Shrapnel.locked then
		shrapnelPanel:SetScript('OnDragStart', nil)
		shrapnelPanel:SetScript('OnDragStop', nil)
		shrapnelPanel:RegisterForDrag(nil)
		shrapnelPreviousPanel:EnableMouse(false)
		shrapnelCooldownPanel:EnableMouse(false)
		shrapnelInterruptPanel:EnableMouse(false)
		shrapnelTrapPanel:EnableMouse(false)
	else
		if not Shrapnel.aoe then
			shrapnelPanel:SetScript('OnDragStart', shrapnelPanel.StartMoving)
			shrapnelPanel:SetScript('OnDragStop', shrapnelPanel.StopMovingOrSizing)
			shrapnelPanel:RegisterForDrag('LeftButton')
		end
		shrapnelPreviousPanel:EnableMouse(true)
		shrapnelCooldownPanel:EnableMouse(true)
		shrapnelInterruptPanel:EnableMouse(true)
		shrapnelTrapPanel:EnableMouse(true)
	end
end

local function OnResourceFrameHide()
	if Shrapnel.snap then
		shrapnelPanel:ClearAllPoints()
	end
end

local function OnResourceFrameShow()
	if Shrapnel.snap then
		shrapnelPanel:ClearAllPoints()
		if Shrapnel.snap == 'above' then
			shrapnelPanel:SetPoint('BOTTOM', NamePlatePlayerResourceFrame, 'TOP', 0, 42)
		elseif Shrapnel.snap == 'below' then
			shrapnelPanel:SetPoint('TOP', NamePlatePlayerResourceFrame, 'BOTTOM', 0, -16)
		end
	end
end

NamePlatePlayerResourceFrame:HookScript("OnHide", OnResourceFrameHide)
NamePlatePlayerResourceFrame:HookScript("OnShow", OnResourceFrameShow)

local function UpdateAlpha()
	shrapnelPanel:SetAlpha(Shrapnel.alpha)
	shrapnelPreviousPanel:SetAlpha(Shrapnel.alpha)
	shrapnelCooldownPanel:SetAlpha(Shrapnel.alpha)
	shrapnelInterruptPanel:SetAlpha(Shrapnel.alpha)
	shrapnelTrapPanel:SetAlpha(Shrapnel.alpha)
end

local function UpdateHealthArray()
	Target.healthArray = {}
	for i = 1, floor(3 / Shrapnel.frequency) do
		Target.healthArray[i] = 0
	end
end

local function UpdateCombat()
	UpdateVars()
	var.main = DetermineAbility()
	if var.main ~= var.last_main then
		if var.main then
			shrapnelPanel.icon:SetTexture(var.main.icon)
			shrapnelPanel.icon:Show()
			shrapnelPanel.border:Show()
		else
			shrapnelPanel.icon:Hide()
			shrapnelPanel.border:Hide()
		end
	end
	if var.cd ~= var.last_cd then
		if var.cd then
			shrapnelCooldownPanel.icon:SetTexture(var.cd.icon)
			shrapnelCooldownPanel:Show()
		else
			shrapnelCooldownPanel:Hide()
		end
	end
	if var.trap ~= var.last_trap then
		if var.trap then
			shrapnelTrapPanel.icon:SetTexture(var.trap.icon)
			shrapnelTrapPanel:Show()
		else
			shrapnelTrapPanel:Hide()
		end
	end
	if Shrapnel.gcd then
		local gcdStart, gcdDuration = GetSpellCooldown(EagleEye.spellId)
		if gcdStart == 0 then
			shrapnelPanel.gcd:Hide()
		else
			shrapnelPanel.gcd:SetCooldown(gcdStart, gcdDuration)
			shrapnelPanel.gcd:Show()
		end
	end
	if Shrapnel.dimmer then
		if not var.main or IsUsableSpell(var.main.spellId) then
			shrapnelPanel.dimmer:Hide()
		else
			shrapnelPanel.dimmer:Show()
		end
	end
	if Shrapnel.interrupt then
		UpdateInterrupt()
	end
	UpdateGlows()
	abilityTimer = 0
end

function events:ADDON_LOADED(name)
	if name == 'Shrapnel' then
		if not Shrapnel.frequency then
			print('It looks like this is your first time getting Shrapneled, why don\'t you take some time to familiarize yourself with the commands?')
			print('Type |cFFFFD000/shrapnel|r for a list of commands.')
		end
		if UnitLevel('player') < 100 then
			print('[|cFFFFD000Warning|r] Shrapnel is not designed for players under level 100, and almost certainly will not operate properly!')
		end
		InitializeVariables()
		UpdateHealthArray()
		UpdateDraggable()
		UpdateAlpha()
		shrapnelPanel:SetScale(Shrapnel.scale.main)
		shrapnelPreviousPanel:SetScale(Shrapnel.scale.previous)
		shrapnelCooldownPanel:SetScale(Shrapnel.scale.cooldown)
		shrapnelInterruptPanel:SetScale(Shrapnel.scale.interrupt)
		shrapnelTrapPanel:SetScale(Shrapnel.scale.trap)
	end
end

function events:COMBAT_LOG_EVENT_UNFILTERED(self, eventType, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags, spellId, spellName)
	if srcGUID ~= me then
		return
	end
	if eventType == 'SPELL_CAST_SUCCESS' then
		local castedAbility = abilityBySpellId[spellId]
		if castedAbility then
			var.last_ability = castedAbility
			if var.last_ability.triggers_gcd then
				var.last_gcd = var.last_ability
			end
			if Shrapnel.previous and shrapnelPanel:IsVisible() then
				shrapnelPreviousPanel.border:SetTexture('Interface\\AddOns\\Shrapnel\\border.blp')
				shrapnelPreviousPanel.icon:SetTexture(var.last_ability.icon)
				shrapnelPreviousPanel:Show()
			end
		end
		if Shrapnel.auto_aoe then
			if spellId == ArcaneShot.spellId then
				Shrapnel_SetTargetMode(1)
			elseif spellId == MultiShot.spellId then
				MultiShot.first_hit_time = nil
			elseif spellId == Butchery.spellId then
				Butchery.first_hit_time = nil
			elseif spellId == Carve.spellId then
				Carve.first_hit_time = nil
			end
		end
		return
	end
	if eventType == 'SPELL_MISSED' then
		if Shrapnel.previous and shrapnelPanel:IsVisible() and Shrapnel.miss_effect and var.last_ability and spellId == var.last_ability.spellId then
			shrapnelPreviousPanel.border:SetTexture('Interface\\AddOns\\Shrapnel\\misseffect.blp')
		end
		return
	end
	if eventType == 'SPELL_DAMAGE' then
		if Shrapnel.auto_aoe then
			if spellId == MultiShot.spellId then
				MultiShot:recordTargetsHit()
			elseif spellId == Butchery.spellId then
				Butchery:recordTargetsHit()
			elseif spellId == Carve.spellId then
				Carve:recordTargetsHit()
			end
		end
	end
end

local function UpdateTargetInfo()
	if ShouldHide() then
		Disappear()
		return false
	end
	local guid = UnitGUID('target')
	if not guid then
		Target.guid = nil
		Target.boss = false
		Target.hostile = true
		for i = 1, #Target.healthArray do
			Target.healthArray[i] = 0
		end
		if Shrapnel.always_on then
			UpdateCombat()
			shrapnelPanel:Show()
			return true
		end
		Disappear()
		return
	end
	if guid ~= Target.guid then
		Target.guid = UnitGUID('target')
		for i = 1, #Target.healthArray do
			Target.healthArray[i] = UnitHealth('target')
		end
	end
	Target.level = UnitLevel('target')
	Target.boss = Target.level == -1 or (Target.level >= UnitLevel('player') + 2 and not UnitInRaid('player'))
	Target.hostile = UnitCanAttack('player', 'target') and not UnitIsDead('target')
	if Target.hostile or Shrapnel.always_on then
		UpdateCombat()
		shrapnelPanel:Show()
		return true
	end
	Disappear()
end

function events:PLAYER_TARGET_CHANGED()
	UpdateTargetInfo()
end

function events:UNIT_FACTION(unitID)
	if unitID == 'target' then
		UpdateTargetInfo()
	end
end

function events:UNIT_FLAGS(unitID)
	if unitID == 'target' then
		UpdateTargetInfo()
	end
end

function events:PLAYER_REGEN_DISABLED()
	combatStartTime = GetTime()
end

function events:PLAYER_REGEN_ENABLED()
	combatStartTime = 0
	if Shrapnel.auto_aoe then
		Shrapnel_SetTargetMode(1)
	end
end

function events:PLAYER_EQUIPMENT_CHANGED()
	Tier.T19P = EquippedTier('Eagletalon ')
	ItemEquipped.FrizzosFingertrap = Equipped("Frizzo's Fingertrap")
end

function events:PLAYER_SPECIALIZATION_CHANGED(unitName)
	if unitName == 'player' then
		for i = 1, #abilities do
			abilities[i].name, _, abilities[i].icon = GetSpellInfo(abilities[i].spellId)
			abilities[i].known = IsPlayerSpell(abilities[i].spellId)
		end
		T19Survival4P.known = Tier.T19P >= 4
		currentSpec = GetSpecialization() or 0
		Shrapnel_SetTargetMode(1)
		UpdateTargetInfo()
	end
end

function events:PLAYER_ENTERING_WORLD()
	events:PLAYER_EQUIPMENT_CHANGED()
	events:PLAYER_SPECIALIZATION_CHANGED('player')
	if #glows == 0 then
		CreateOverlayGlows()
	end
end

shrapnelPanel.button:SetScript('OnClick', function(self, button, down)
	if down then
		if button == 'LeftButton' then
			Shrapnel_ToggleTargetMode()
		elseif button == 'RightButton' then
			Shrapnel_ToggleTargetModeReverse()
		elseif button == 'MiddleButton' then
			Shrapnel_SetTargetMode(1)
		end
	end
end)

shrapnelPanel:SetScript('OnUpdate', function(self, elapsed)
	abilityTimer = abilityTimer + elapsed
	if abilityTimer >= Shrapnel.frequency then
		if Shrapnel.auto_aoe then
			if currentSpec == SPEC.MARKSMANSHIP then
				MultiShot:updateTargetsHit()
			elseif currentSpec == SPEC.SURVIVAL then
				Butchery:updateTargetsHit()
				Carve:updateTargetsHit()
			end
		end
		UpdateCombat()
	end
end)

shrapnelPanel:SetScript('OnEvent', function(self, event, ...) events[event](self, ...) end)
for event in pairs(events) do
	shrapnelPanel:RegisterEvent(event)
end

function SlashCmdList.Shrapnel(msg, editbox)
	msg = { strsplit(' ', strlower(msg)) }
	if startsWith(msg[1], 'lock') then
		if msg[2] then
			Shrapnel.locked = msg[2] == 'on'
			UpdateDraggable()
		end
		return print('Shrapnel - Locked: ' .. (Shrapnel.locked and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if startsWith(msg[1], 'snap') then
		if msg[2] then
			if msg[2] == 'above' or msg[2] == 'over' then
				Shrapnel.snap = 'above'
			elseif msg[2] == 'below' or msg[2] == 'under' then
				Shrapnel.snap = 'below'
			else
				Shrapnel.snap = false
				shrapnelPanel:ClearAllPoints()
			end
			OnResourceFrameShow()
		end
		return print('Shrapnel - Snap to Blizzard combat resources frame: ' .. (Shrapnel.snap and ('|cFF00C000' .. Shrapnel.snap) or '|cFFC00000Off'))
	end
	if msg[1] == 'scale' then
		if startsWith(msg[2], 'prev') then
			if msg[3] then
				Shrapnel.scale.previous = tonumber(msg[3]) or 0.7
				shrapnelPreviousPanel:SetScale(Shrapnel.scale.previous)
			end
			return print('Shrapnel - Previous ability icon scale set to: |cFFFFD000' .. Shrapnel.scale.previous .. '|r times')
		end
		if msg[2] == 'main' then
			if msg[3] then
				Shrapnel.scale.main = tonumber(msg[3]) or 1
				shrapnelPanel:SetScale(Shrapnel.scale.main)
			end
			return print('Shrapnel - Main ability icon scale set to: |cFFFFD000' .. Shrapnel.scale.main .. '|r times')
		end
		if msg[2] == 'cd' then
			if msg[3] then
				Shrapnel.scale.cooldown = tonumber(msg[3]) or 0.7
				shrapnelCooldownPanel:SetScale(Shrapnel.scale.cooldown)
			end
			return print('Shrapnel - Cooldown ability icon scale set to: |cFFFFD000' .. Shrapnel.scale.cooldown .. '|r times')
		end
		if startsWith(msg[2], 'int') then
			if msg[3] then
				Shrapnel.scale.interrupt = tonumber(msg[3]) or 0.4
				shrapnelInterruptPanel:SetScale(Shrapnel.scale.interrupt)
			end
			return print('Shrapnel - Interrupt ability icon scale set to: |cFFFFD000' .. Shrapnel.scale.interrupt .. '|r times')
		end
		if startsWith(msg[2], 'trap') then
			if msg[3] then
				Shrapnel.scale.trap = tonumber(msg[3]) or 0.4
				shrapnelInterruptPanel:SetScale(Shrapnel.scale.trap)
			end
			return print('Shrapnel - Trap ability icon scale set to: |cFFFFD000' .. Shrapnel.scale.trap .. '|r times')
		end
		if msg[2] == 'glow' then
			if msg[3] then
				Shrapnel.scale.glow = tonumber(msg[3]) or 1
				UpdateGlowColorAndScale()
			end
			return print('Shrapnel - Action button glow scale set to: |cFFFFD000' .. Shrapnel.scale.glow .. '|r times')
		end
		return print('Shrapnel - Default icon scale options: |cFFFFD000prev 0.7|r, |cFFFFD000main 1|r, |cFFFFD000cd 0.7|r, |cFFFFD000interrupt 0.4|r, and |cFFFFD000glow 1|r')
	end
	if msg[1] == 'alpha' then
		if msg[2] then
			Shrapnel.alpha = max(min((tonumber(msg[2]) or 100), 100), 0) / 100
			UpdateAlpha()
		end
		return print('Shrapnel - Icon transparency set to: |cFFFFD000' .. Shrapnel.alpha * 100 .. '%|r')
	end
	if startsWith(msg[1], 'freq') then
		if msg[2] then
			Shrapnel.frequency = tonumber(msg[2]) or 0.05
			UpdateHealthArray()
		end
		return print('Shrapnel - Calculation frequency: Every |cFFFFD000' .. Shrapnel.frequency .. '|r seconds')
	end
	if startsWith(msg[1], 'glow') then
		if msg[2] == 'main' then
			if msg[3] then
				Shrapnel.glow.main = msg[3] == 'on'
				UpdateGlows()
			end
			return print('Shrapnel - Glowing ability buttons (main icon): ' .. (Shrapnel.glow.main and '|cFF00C000On' or '|cFFC00000Off'))
		end
		if msg[2] == 'cd' then
			if msg[3] then
				Shrapnel.glow.cooldown = msg[3] == 'on'
				UpdateGlows()
			end
			return print('Shrapnel - Glowing ability buttons (cooldown icon): ' .. (Shrapnel.glow.cooldown and '|cFF00C000On' or '|cFFC00000Off'))
		end
		if startsWith(msg[2], 'int') then
			if msg[3] then
				Shrapnel.glow.interrupt = msg[3] == 'on'
				UpdateGlows()
			end
			return print('Shrapnel - Glowing ability buttons (interrupt icon): ' .. (Shrapnel.glow.interrupt and '|cFF00C000On' or '|cFFC00000Off'))
		end
		if startsWith(msg[2], 'trap') then
			if msg[3] then
				Shrapnel.glow.trap = msg[3] == 'on'
				UpdateGlows()
			end
			return print('Shrapnel - Glowing ability buttons (trap icon): ' .. (Shrapnel.glow.trap and '|cFF00C000On' or '|cFFC00000Off'))
		end
		if startsWith(msg[2], 'bliz') then
			if msg[3] then
				Shrapnel.glow.blizzard = msg[3] == 'on'
				UpdateGlows()
			end
			return print('Shrapnel - Blizzard default proc glow: ' .. (Shrapnel.glow.blizzard and '|cFF00C000On' or '|cFFC00000Off'))
		end
		if msg[2] == 'color' then
			if msg[5] then
				Shrapnel.glow.color.r = max(min(tonumber(msg[3]) or 0, 1), 0)
				Shrapnel.glow.color.g = max(min(tonumber(msg[4]) or 0, 1), 0)
				Shrapnel.glow.color.b = max(min(tonumber(msg[5]) or 0, 1), 0)
				UpdateGlowColorAndScale()
			end
			return print('Shrapnel - Glow color:', '|cFFFF0000' .. Shrapnel.glow.color.r, '|cFF00FF00' .. Shrapnel.glow.color.g, '|cFF0000FF' .. Shrapnel.glow.color.b)
		end
		return print('Shrapnel - Possible glow options: |cFFFFD000main|r, |cFFFFD000cd|r, |cFFFFD000interrupt|r, |cFFFFD000blizzard|r, and |cFFFFD000color')
	end
	if startsWith(msg[1], 'prev') then
		if msg[2] then
			Shrapnel.previous = msg[2] == 'on'
			UpdateTargetInfo()
		end
		return print('Shrapnel - Previous ability icon: ' .. (Shrapnel.previous and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if msg[1] == 'always' then
		if msg[2] then
			Shrapnel.always_on = msg[2] == 'on'
			UpdateTargetInfo()
		end
		return print('Shrapnel - Show the Shrapnel UI without a target: ' .. (Shrapnel.always_on and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if msg[1] == 'cd' then
		if msg[2] then
			Shrapnel.cooldown = msg[2] == 'on'
		end
		return print('Shrapnel - Use Shrapnel for cooldown management: ' .. (Shrapnel.cooldown and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if msg[1] == 'gcd' then
		if msg[2] then
			Shrapnel.gcd = msg[2] == 'on'
			if not Shrapnel.gcd then
				shrapnelPanel.gcd:Hide()
			end
		end
		return print('Shrapnel - Global cooldown swipe: ' .. (Shrapnel.gcd and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if startsWith(msg[1], 'dim') then
		if msg[2] then
			Shrapnel.dimmer = msg[2] == 'on'
			if not Shrapnel.dimmer then
				shrapnelPanel.dimmer:Hide()
			end
		end
		return print('Shrapnel - Dim main ability icon when you don\'t have enough focus to use it: ' .. (Shrapnel.dimmer and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if msg[1] == 'miss' then
		if msg[2] then
			Shrapnel.miss_effect = msg[2] == 'on'
		end
		return print('Shrapnel - Red border around previous ability when it fails to hit: ' .. (Shrapnel.miss_effect and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if msg[1] == 'aoe' then
		if msg[2] then
			Shrapnel.aoe = msg[2] == 'on'
			Shrapnel_SetTargetMode(1)
			UpdateDraggable()
		end
		return print('Shrapnel - Allow clicking main ability icon to toggle amount of targets (disables moving): ' .. (Shrapnel.aoe and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if msg[1] == 'bossonly' then
		if msg[2] then
			Shrapnel.boss_only = msg[2] == 'on'
		end
		return print('Shrapnel - Only use cooldowns on bosses: ' .. (Shrapnel.boss_only and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if msg[1] == 'hidespec' or startsWith(msg[1], 'spec') then
		if msg[2] then
			if startsWith(msg[2], 'b') then
				Shrapnel.hide.bm = not Shrapnel.hide.bm
				events:PLAYER_SPECIALIZATION_CHANGED('player')
				return print('Shrapnel - Beast Mastery specialization: |cFFFFD000' .. (Shrapnel.hide.bm and '|cFFC00000Off' or '|cFF00C000On'))
			end
			if startsWith(msg[2], 'm') then
				Shrapnel.hide.mm = not Shrapnel.hide.mm
				events:PLAYER_SPECIALIZATION_CHANGED('player')
				return print('Shrapnel - Marksmanship specialization: |cFFFFD000' .. (Shrapnel.hide.mm and '|cFFC00000Off' or '|cFF00C000On'))
			end
			if startsWith(msg[2], 's') then
				Shrapnel.hide.sv = not Shrapnel.hide.sv
				events:PLAYER_SPECIALIZATION_CHANGED('player')
				return print('Shrapnel - Survival specialization: |cFFFFD000' .. (Shrapnel.hide.sv and '|cFFC00000Off' or '|cFF00C000On'))
			end
		end
		return print('Shrapnel - Possible hidespec options: |cFFFFD000aff|r/|cFFFFD000demo|r/|cFFFFD000dest|r - toggle disabling Shrapnel for specializations')
	end
	if startsWith(msg[1], 'int') then
		if msg[2] then
			Shrapnel.interrupt = msg[2] == 'on'
		end
		return print('Shrapnel - Show an icon for interruptable spells: ' .. (Shrapnel.interrupt and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if startsWith(msg[1], 'trap') then
		if msg[2] then
			Shrapnel.trap = msg[2] == 'on'
		end
		return print('Shrapnel - Show an icon for traps (Survival): ' .. (Shrapnel.trap and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if msg[1] == 'st90' then
		if msg[2] then
			Shrapnel.single_90 = msg[2] == 'on'
		end
		return print('Shrapnel - Use level 90 talents in single target mode: ' .. (Shrapnel.single_90 and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if msg[1] == 'auto' then
		if msg[2] then
			Shrapnel.auto_aoe = msg[2] == 'on'
		end
		return print('Shrapnel - Automatically change target mode on AoE spells: ' .. (Shrapnel.auto_aoe and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if startsWith(msg[1], 'pot') then
		if msg[2] then
			Shrapnel.pot = msg[2] == 'on'
		end
		return print('Shrapnel - Show Prolonged Power potions in cooldown UI: ' .. (Shrapnel.pot and '|cFF00C000On' or '|cFFC00000Off'))
	end
	if msg[1] == 'reset' then
		shrapnelPanel:ClearAllPoints()
		shrapnelPanel:SetPoint('CENTER', 0, -169)
		shrapnelPreviousPanel:ClearAllPoints()
		shrapnelPreviousPanel:SetPoint('BOTTOMRIGHT', shrapnelPanel, 'BOTTOMLEFT', -10, -5)
		shrapnelCooldownPanel:ClearAllPoints()
		shrapnelCooldownPanel:SetPoint('BOTTOMLEFT', shrapnelPanel, 'BOTTOMRIGHT', 10, -5)
		shrapnelInterruptPanel:ClearAllPoints()
		shrapnelInterruptPanel:SetPoint('TOPLEFT', shrapnelPanel, 'TOPRIGHT', 16, 25)
		shrapnelTrapPanel:ClearAllPoints()
		shrapnelTrapPanel:SetPoint('TOPRIGHT', shrapnelPanel, 'TOPLEFT', -16, 25)
		return print('Shrapnel - Position has been reset to default')
	end
	print('Shrapnel (version: |cFFFFD000' .. GetAddOnMetadata('Shrapnel', 'Version') .. '|r) - Commands:')
	local _, cmd
	for _, cmd in next, {
		'locked |cFF00C000on|r/|cFFC00000off|r - lock the Shrapnel UI so that it can\'t be moved',
		'snap |cFF00C000above|r/|cFF00C000below|r/|cFFC00000off|r - snap the Shrapnel UI to the Blizzard combat resources frame',
		'scale |cFFFFD000prev|r/|cFFFFD000main|r/|cFFFFD000cd|r/|cFFFFD000interrupt|r/|cFFFFD000trap|r/|cFFFFD000glow|r - adjust the scale of the Shrapnel UI icons',
		'alpha |cFFFFD000[percent]|r - adjust the transparency of the Shrapnel UI icons',
		'frequency |cFFFFD000[number]|r - set the calculation frequency (default is every 0.05 seconds)',
		'glow |cFFFFD000main|r/|cFFFFD000cd|r/|cFFFFD000interrupt|r/|cFFFFD000trap|r/|cFFFFD000blizzard|r |cFF00C000on|r/|cFFC00000off|r - glowing ability buttons on action bars',
		'glow color |cFFF000000.0-1.0|r |cFF00FF000.1-1.0|r |cFF0000FF0.0-1.0|r - adjust the color of the ability button glow',
		'previous |cFF00C000on|r/|cFFC00000off|r - previous ability icon',
		'always |cFF00C000on|r/|cFFC00000off|r - show the Shrapnel UI without a target',
		'cd |cFF00C000on|r/|cFFC00000off|r - use Shrapnel for cooldown management',
		'gcd |cFF00C000on|r/|cFFC00000off|r - show global cooldown swipe on main ability icon',
		'dim |cFF00C000on|r/|cFFC00000off|r - dim main ability icon when you don\'t have enough focus to use it',
		'miss |cFF00C000on|r/|cFFC00000off|r - red border around previous ability when it fails to hit',
		'aoe |cFF00C000on|r/|cFFC00000off|r - allow clicking main ability icon to toggle amount of targets (disables moving)',
		'bossonly |cFF00C000on|r/|cFFC00000off|r - only use cooldowns on bosses',
		'hidespec |cFFFFD000aff|r/|cFFFFD000demo|r/|cFFFFD000dest|r - toggle disabling Shrapnel for specializations',
		'interrupt |cFF00C000on|r/|cFFC00000off|r - show an icon for interruptable spells',
		'trap |cFF00C000on|r/|cFFC00000off|r - show an icon for traps (survival)',
		'st90 |cFF00C000on|r/|cFFC00000off|r - use level 90 talents in single target mode',
		'auto |cFF00C000on|r/|cFFC00000off|r  - automatically change target mode on AoE spells',
		'pot |cFF00C000on|r/|cFFC00000off|r - show Prolonged Power potions in cooldown UI',
		'|cFFFFD000reset|r - reset the location of the Shrapnel UI to default',
	} do
		print('  ' .. SLASH_Shrapnel1 .. ' ' .. cmd)
	end
	print('Got ideas for improvement or found a bug? Contact |cFFABD473Firearm|cFFFFD000-Mal\'Ganis|r or |cFFFFD000Spy#1955|r (the author of this addon)')
end
