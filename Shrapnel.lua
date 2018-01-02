if select(2, UnitClass('player')) ~= 'HUNTER' then
	DisableAddOn('Shrapnel')
	return
end

Shrapnel = {}

SLASH_Shrapnel1, SLASH_Shrapnel2 = '/shrapnel', '/shr'
BINDING_HEADER_SHRAPNEL = 'Shrapnel'

local function InitializeVariables()
	for k, v in pairs({ -- defaults
		locked = false,
		snap = false,
		scale_main = 1,
		scale_previous = 0.7,
		scale_cooldown = 0.7,
		scale_trap = 0.4,
		scale_interrupt = 0.4,
		scale_glow = 1,
		alpha = 1,
		frequency = 0.05,
		previous = true,
		always_on = false,
		cooldown = true,
		aoe = false,
		gcd = true,
		dimmer = true,
		miss_effect = true,
		glow_main = true,
		glow_cooldown = true,
		glow_trap = true,
		glow_interrupt = false,
		glow_blizzard = false,
		glow_color = { r = 1, g = 1, b = 1 },
		boss_only = false,
		hide_bm = false,
		hide_mm = false,
		hide_sv = false,
		trap = true,
		interrupt = true,
		single_90 = false,
		auto_aoe = false,
		pot = false
	}) do
		if Shrapnel[k] == nil then
			Shrapnel[k] = v
		end
	end
end

local SPEC_NONE = 0
local SPEC_BEAST_MASTERY = 1
local SPEC_MARKSMANSHIP = 2
local SPEC_SURVIVAL = 3

local events, abilities, ability, glows = {}, {}, {}, {}

local me, abilityTimer, currentSpec, targetMode, combatStartTime = 0, 0, 0, 0, 0

local T19P = 0
local FrizzosFingertrap = false

local var = {
	gcd = 0
}

local targetModes = {
	[SPEC_NONE] = { {1, ''} },
	[SPEC_BEAST_MASTERY] = {
		{1, ''},
		{2, '2+'},
		{6, '6+'}
	},
	[SPEC_MARKSMANSHIP] = {
		{1, ''},
		{2, '2+'},
		{4, '4+'},
		{6, '6+'}
	},
	[SPEC_SURVIVAL] = {
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

local Ability = {}
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
		requires_charge = false,
		requires_pet = false,
		known = IsPlayerSpell(spellId),
		auraTarget = buff == 'pet' and 'pet' or buff and 'player' or 'target',
		auraFilter = (buff and 'HELPFUL' or 'HARMFUL') .. (player and '|PLAYER' or '')
	}
	setmetatable(ability, Ability)
	abilities[#abilities + 1] = ability
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
	local _, id, expires
	for i = 1, 40 do
		_, _, _, _, _, _, expires, _, _, _, id = UnitAura(self.auraTarget, i, self.auraFilter)
		if id == self.spellId or id == self.spellId2 then
			return max(expires - var.time - var.cast_remains, 0)
		end
	end
	return 0
end

function Ability:refreshable()
	if self.buff_duration > 0 then
		return self:remains() < self.buff_duration * 0.3
	end
	return self:down()
end

function Ability:up()
	local _, id, expires
	for i = 1, 40 do
		_, _, _, _, _, _, expires, _, _, _, id = UnitAura(self.auraTarget, i, self.auraFilter)
		if id == self.spellId or id == self.spellId2 then
			return expires - var.time > var.cast_remains
		end
	end
end

function Ability:down()
	return not self:up()
end

function Ability:cooldown()
	if self.cooldown_duration > 0 and self:casting() then
		return self.cooldown_duration + var.cast_remains
	end
	local start, duration = GetSpellCooldown(self.spellId)
	return start > 0 and max(0, (duration - (var.time - start))) - var.cast_remains or 0
end

function Ability:stack()
	local _, id, expires, count
	for i = 1, 40 do
		_, _, _, count, _, _, expires, _, _, _, id = UnitAura(self.auraTarget, i, self.auraFilter)
		if id == self.spellId or id == self.spellId2 then
			return expires - var.time > var.cast_remains and count or 0
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

function Ability:casting()
	return var.cast_name == self.name or var.execute_name == self.name
end

function Ability:castTime()
	local _, _, _, castTime = GetSpellInfo(self.spellId)
	return castTime / 1000
end

function Ability:castRegen()
	return var.regen * max(1, self:castTime())
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
FlankingStrike.focus_cost = 45
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
	ability.last_main = ability.main
	ability.last_trap = ability.trap
	ability.last_cd = ability.cd
	var.time = GetTime()
	var.gcd = 1.5 - (1.5 * (UnitSpellHaste('player') / 100))
	start, duration = GetSpellCooldown(EagleEye.spellId)
	var.gcd_remains = start > 0 and duration - (var.time - start) or 0
	if var.execute_name and var.gcd_remains < 0.2 then
		var.execute_name = nil
	end
	var.cast_name, _, _, _, _, remains = UnitCastingInfo('player')
	if not remains then
		var.cast_name, _, _, _, _, remains = UnitChannelInfo('player')
	end
	var.cast_remains = remains and remains / 1000 - var.time or var.gcd_remains
	var.cast_ability = GetAbilityCasting()
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

local function GCD()
	return var.gcd
end

local function GCDRemains()
	return var.gcd_remains
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

local function UseCooldown(overwrite)
	return Shrapnel.cooldown and (not Shrapnel.boss_only or Target.boss) and (not ability.cd or overwrite)
end

local function UseTrap(overwrite)
	return Shrapnel.trap and (not ability.trap or overwrite)
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

local function DetermineAbilityMarksmanship()
	--if UseCooldown() and Volley.known and Volley:down() then
	--	ability.cd = Volley
	--end
	MM_Var.PoolingForPiercing = PiercingShot.known and PiercingShot:cooldown() < 5 and Vulnerable:up() and Vulnerable:remains() > PiercingShot:cooldown() and (Trueshot:down() or Enemies() == 1)
	MM_Var.WaitingForSentinel = Sentinel.known and (MarkingTargets:up() or Trueshot:up()) and not Sentinel:ready() and ((Sentinel:cooldown() > 54 and Sentinel:cooldown() < (54 + GCD())) or (Sentinel:cooldown() > 48 and Sentinel:cooldown() < (48 + GCD())) or (Sentinel:cooldown() > 42 and Sentinel:cooldown() < (42 + GCD())))
	if TimeInCombat() > 15 and Trueshot:ready() and MM_Var.TrueshotCooldown == 0 then
		MM_Var.TrueshotCooldown = TimeInCombat() * 1.1
	end
	if UseCooldown() and Trueshot:ready() and (MM_Var.TrueshotCooldown == 0 or BloodlustActive() or (MM_Var.TrueshotCooldown > 0 and Target.timeToDie > (MM_Var.TrueshotCooldown + 15)) or Bullseye:stack() > 25 or Target.timeToDie < 16) then
		ability.cd = Trueshot
	end
	if Enemies() == 1 and Target.timeToDie < 6 then
		return APL_MM_TargetDie()
	end
	if PatientSniper.known then
		return APL_MM_PatientSniper()
	end
	return APL_MM_NonPatientSniper()
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
	if UseCooldown() and SnakeHunter.known and SnakeHunter:ready() and MongooseBite:charges() == 0 and MongooseFury:remains() > 3 * GCD() and TimeInCombat() > 15 then
		ability.cd = SnakeHunter
	end
	if UseCooldown() and SpittingCobra.known and SpittingCobra:ready() and MongooseFury:remains() >= GCD() and MongooseFury:stack() < 4 and MokNathalTactics:stack() >= 3 then
		ability.cd = SpittingCobra
	end
	if UseTrap() and SteelTrap.known and SteelTrap:ready() and Target.timeToDie > 6 and MongooseFury:down() then
		ability.trap = SteelTrap
	end
	if AMurderOfCrowsSV.known and AMurderOfCrowsSV:ready() and Target.timeToDie > 6 and Focus() > (55 - MokNathalTactics:remains() * FocusRegen()) and MongooseFury:stack() < 4 and MongooseFury:remains() >= GCD() then
		return AMurderOfCrowsSV
	end
	if FlankingStrike:usable() and MongooseBite:charges() <= 1 and Focus() > (75 - MokNathalTactics:remains() * FocusRegen()) then
		return FlankingStrike
	end
	if FrizzosFingertrap and Lacerate:up() and Lacerate:refreshable() and Focus() > (65 - MokNathalTactics:remains() * FocusRegen()) and MongooseFury:remains() >= GCD() then
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
	if UseTrap() and Caltrops.known and Caltrops:ready() and (Enemies() > 1 or Target.timeToDie > 8) and Caltrops:down() and MongooseFury:down() then
		ability.trap = Caltrops
	end
	if UseTrap() and ExplosiveTrap:ready() and (Enemies() > 1 or Target.timeToDie > 4) and MongooseFury:down() and MongooseBite:charges() == 0 then
		ability.trap = ExplosiveTrap
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
	if UseTrap() and DragonsfireGrenade.known and DragonsfireGrenade:ready() and MongooseFury:down() then
		ability.trap = DragonsfireGrenade
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
	if UseCooldown() and AspectOfTheEagle:ready() and ((MongooseFury:stack() > 4 and TimeInCombat() < 15) or (MongooseFury:stack() > 1 and TimeInCombat() > 15) or (MongooseFury:remains() > 6 and MongooseBite:charges() < 2)) then
		ability.cd = AspectOfTheEagle
	end
	if MongooseBite:usable() and MongooseFury:up() and MongooseFury:remains() < AspectOfTheEagle:cooldown() then
		return MongooseBite
	end
	if UseCooldown() and SpittingCobra:ready() then
		ability.cd = SpittingCobra
	end
	if UseTrap() and SteelTrap.known and SteelTrap:ready() and Target.timeToDie > 6 then
		ability.trap = SteelTrap
	end
	if AMurderOfCrowsSV.known and AMurderOfCrowsSV:usable() and Target.timeToDie > 6 and Focus() > (55 - MokNathalTactics:remains() * FocusRegen()) then
		return AMurderOfCrowsSV
	end
	if UseTrap() then
		if Caltrops.known and Caltrops:ready() and Caltrops:down() and (Enemies() > 1 or Target.timeToDie > 8) then
			ability.trap = Caltrops
		elseif ExplosiveTrap:ready() and (Enemies() > 1 or Target.timeToDie > 4) then
			ability.trap = ExplosiveTrap
		end
	end
	if FrizzosFingertrap and Lacerate:up() and Lacerate:refreshable() and Focus() > (65 - MokNathalTactics:remains() * FocusRegen()) then
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
	if UseTrap() and DragonsfireGrenade.known and DragonsfireGrenade:ready() then
		ability.trap = DragonsfireGrenade
	end
	if MongooseBite:ready() and (MongooseBite:charges() >= 3 or (MongooseBite:charges() == 2 and MongooseBite:cooldown() <= GCD())) then
		return MongooseBite
	end
	if FlankingStrike:usable() then
		return FlankingStrike
	end
	if UseCooldown() and OnTheTrail:down() and Harpoon:ready() then
		ability.cd = Harpoon
	end
	if Butchery.known and Butchery:usable() and (Focus() > (65 - MokNathalTactics:remains() * FocusRegen()) or (Enemies() == 1 and Target.timeToDie < 2)) then
		return Butchery
	end
	if RaptorStrike:usable() and (Focus() > (75 - FlankingStrike:cooldown() * FocusRegen()) or (Enemies() == 1 and Target.timeToDie < 2)) then
		return RaptorStrike
	end
end

local function DetermineAbilitySurvival()
	if TimeInCombat() == 0 and UseCooldown() and OnTheTrail:down() and Harpoon:ready() then
		ability.cd = Harpoon
	end
	return DetermineAbilitySurvivalMokNathal()
end

local function DetermineAbility()
	ability.cd = nil
	ability.trap = nil
	if currentSpec == SPEC_BEAST_MASTERY then
		return DetermineAbilityBeastMastery()
	elseif currentSpec == SPEC_MARKSMANSHIP then
		return DetermineAbilityMarksmanship()
	elseif currentSpec == SPEC_SURVIVAL then
		return DetermineAbilitySurvival()
	end
	shrapnelPreviousPanel:Hide()
end

local function DetermineInterrupt()
	if CounterShot.known then
		return CounterShot:ready() and CounterShot
	end
	if Muzzle.known then
		return Muzzle:ready() and Muzzle
	end
end

local function UpdateInterrupt()
	local _, _, _, _, start, ends, _, _, notInterruptible = UnitCastingInfo('target')
	if not start or notInterruptible then
		ability.interrupt = nil
		shrapnelInterruptPanel:Hide()
		return
	end
	ability.interrupt = DetermineInterrupt()
	if ability.interrupt then
		shrapnelInterruptPanel.icon:SetTexture(ability.interrupt.icon)
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
	if not Shrapnel.glow_blizzard then
		actionButton.overlay:Hide()
	end
end

hooksecurefunc('ActionButton_ShowOverlayGlow', DenyOverlayGlow) -- Disable Blizzard's built-in action button glowing

local function UpdateGlowColorAndScale()
	local w, h, glow
	local r = Shrapnel.glow_color.r
	local g = Shrapnel.glow_color.g
	local b = Shrapnel.glow_color.b
	for i = 1, #glows do
		glow = glows[i]
		w, h = glow.button:GetSize()
		glow:SetSize(w * 1.4, h * 1.4)
		glow:SetPoint('TOPLEFT', glow.button, 'TOPLEFT', -w * 0.2 * Shrapnel.scale_glow, h * 0.2 * Shrapnel.scale_glow)
		glow:SetPoint('BOTTOMRIGHT', glow.button, 'BOTTOMRIGHT', w * 0.2 * Shrapnel.scale_glow, -h * 0.2 * Shrapnel.scale_glow)
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
			(Shrapnel.glow_main and ability.main and icon == ability.main.icon) or
			(Shrapnel.glow_cooldown and ability.cd and icon == ability.cd.icon) or
			(Shrapnel.glow_trap and ability.trap and icon == ability.trap.icon) or
			(Shrapnel.glow_interrupt and ability.interrupt and icon == ability.interrupt.icon)
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
end

local function ShouldHide()
	return (currentSpec == SPEC_NONE or
		   (currentSpec == SPEC_BEAST_MASTERY and Shrapnel.hide_bm) or
		   (currentSpec == SPEC_MARKSMANSHIP and Shrapnel.hide_mm) or
		   (currentSpec == SPEC_SURVIVAL and Shrapnel.hide_sv))
end

local function Disappear()
	ability.main = nil
	ability.cd = nil
	ability.trap = nil
	ability.interrupt = nil
	UpdateGlows()
	shrapnelPanel:Hide()
	shrapnelPanel.border:Hide()
	shrapnelPreviousPanel:Hide()
	shrapnelCooldownPanel:Hide()
	shrapnelTrapPanel:Hide()
	shrapnelInterruptPanel:Hide()
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
	local ilink = GetInventoryItemLink('player', slot)
	if ilink then
		local iname = ilink:match('%[(.*)%]')
		return iname and iname:find(name) and true or false
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
		shrapnelTrapPanel:EnableMouse(false)
		shrapnelInterruptPanel:EnableMouse(false)
	else
		if not Shrapnel.aoe then
			shrapnelPanel:SetScript('OnDragStart', shrapnelPanel.StartMoving)
			shrapnelPanel:SetScript('OnDragStop', shrapnelPanel.StopMovingOrSizing)
			shrapnelPanel:RegisterForDrag('LeftButton')
		end
		shrapnelPreviousPanel:EnableMouse(true)
		shrapnelCooldownPanel:EnableMouse(true)
		shrapnelTrapPanel:EnableMouse(true)
		shrapnelInterruptPanel:EnableMouse(true)
	end
end

local function ResourceFrameHide()
	if Shrapnel.snap then
		shrapnelPanel:ClearAllPoints()
	end
end

local function ResourceFrameShow()
	if Shrapnel.snap then
		shrapnelPanel:ClearAllPoints()
		shrapnelPanel:SetPoint('TOP', NamePlatePlayerResourceFrame, 'BOTTOM', 0, -16)
	end
end

NamePlatePlayerResourceFrame:HookScript("OnHide", ResourceFrameHide)
NamePlatePlayerResourceFrame:HookScript("OnShow", ResourceFrameShow)

local function UpdateAlpha()
	shrapnelPanel:SetAlpha(Shrapnel.alpha)
	shrapnelPreviousPanel:SetAlpha(Shrapnel.alpha)
	shrapnelCooldownPanel:SetAlpha(Shrapnel.alpha)
	shrapnelTrapPanel:SetAlpha(Shrapnel.alpha)
	shrapnelInterruptPanel:SetAlpha(Shrapnel.alpha)
end

local function UpdateHealthArray()
	Target.healthArray = {}
	for i = 1, floor(3 / Shrapnel.frequency) do
		Target.healthArray[i] = 0
	end
end

local function UpdateCombat()
	UpdateVars()
	ability.main = DetermineAbility()
	if ability.main ~= ability.last_main then
		if ability.main then
			shrapnelPanel.icon:SetTexture(ability.main.icon)
			shrapnelPanel.icon:Show()
			shrapnelPanel.border:Show()
		else
			shrapnelPanel.icon:Hide()
			shrapnelPanel.border:Hide()
		end
	end
	if ability.cd ~= ability.last_cd then
		if ability.cd then
			shrapnelCooldownPanel.icon:SetTexture(ability.cd.icon)
			shrapnelCooldownPanel:Show()
		else
			shrapnelCooldownPanel:Hide()
		end
	end
	if ability.trap ~= ability.last_trap then
		if ability.trap then
			shrapnelTrapPanel.icon:SetTexture(ability.trap.icon)
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
		if not ability.main or IsUsableSpell(ability.main.spellId) then
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
		shrapnelPanel:SetScale(Shrapnel.scale_main)
		shrapnelPreviousPanel:SetScale(Shrapnel.scale_previous)
		shrapnelCooldownPanel:SetScale(Shrapnel.scale_cooldown)
		shrapnelTrapPanel:SetScale(Shrapnel.scale_trap)
		shrapnelInterruptPanel:SetScale(Shrapnel.scale_interrupt)
	end
end

function events:COMBAT_LOG_EVENT_UNFILTERED(self, eventType, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags, spellId, spellName)
	if srcGUID == me and Shrapnel.previous and shrapnelPanel:IsVisible() then
		if eventType == 'SPELL_MISSED' and Shrapnel.miss_effect and ability.previous and spellId == ability.previous.spellId then
			shrapnelPreviousPanel.border:SetTexture('Interface\\AddOns\\Shrapnel\\misseffect.blp')
		elseif eventType == 'SPELL_CAST_SUCCESS' then
			var.execute_name = spellName
			if ability.main and spellId == ability.main.spellId then
				ability.previous = ability.main
				shrapnelPreviousPanel.border:SetTexture('Interface\\AddOns\\Shrapnel\\border.blp')
				shrapnelPreviousPanel.icon:SetTexture(ability.previous.icon)
				shrapnelPreviousPanel:Show()
			end
		end
		if Shrapnel.auto_aoe then
			if eventType == 'SPELL_CAST_SUCCESS' then
				if spellId == ArcaneShot.spellId then
					Shrapnel_SetTargetMode(1)
				elseif spellId == MultiShot.spellId then
					MultiShot.first_hit_time = nil
				elseif spellId == Butchery.spellId then
					Butchery.first_hit_time = nil
				elseif spellId == Carve.spellId then
					Carve.first_hit_time = nil
				end
			elseif eventType == 'SPELL_DAMAGE' then
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
end

function events:PLAYER_TARGET_CHANGED()
	if ShouldHide() then
		return
	end
	if ElvUI and #glows == 0 then
		CreateOverlayGlows()
	end
	local previouslyHostile = Target.hostile
	Target.hostile = UnitCanAttack('player', 'target')
	if Target.hostile then
		Target.guid = UnitGUID('target')
		Target.level = UnitLevel('target')
		Target.boss = Target.level == -1 or (Target.level >= UnitLevel('player') + 2 and not UnitInRaid('player'))
		for i = 1, #Target.healthArray do
			Target.healthArray[i] = UnitHealth('target')
		end
		UpdateCombat()
		shrapnelPanel:Show()
	elseif Shrapnel.always_on then
		Target.guid = 0
		Target.boss = false
		Target.hostile = true
		for i = 1, #Target.healthArray do
			Target.healthArray[i] = 0
		end
		UpdateCombat()
		shrapnelPanel:Show()
	elseif previouslyHostile then
		Disappear()
	end
end

function events:PLAYER_REGEN_DISABLED()
	combatStartTime = GetTime()
	MM_Var.TrueshotCooldown = 0
end

function events:PLAYER_REGEN_ENABLED()
	combatStartTime = 0
	if Shrapnel.auto_aoe then
		Shrapnel_SetTargetMode(1)
	end
end

function events:UNIT_FACTION(unitID)
	if unitID == 'target' then
		events:PLAYER_TARGET_CHANGED()
	end
end

function events:PLAYER_EQUIPMENT_CHANGED()
	T19P = EquippedTier('Eagletalon')
	FrizzosFingertrap = Equipped("Frizzo's Fingertrap", 11) or Equipped("Frizzo's Fingertrap", 12)
end

function events:PLAYER_SPECIALIZATION_CHANGED(unitName)
	if unitName == 'player' then
		for i = 1, #abilities do
			abilities[i].name, _, abilities[i].icon = GetSpellInfo(abilities[i].spellId)
			abilities[i].known = IsPlayerSpell(abilities[i].spellId)
		end
		T19Survival4P.known = T19P >= 4
		currentSpec = GetSpecialization() or 0
		if ShouldHide() then
			Disappear()
		end
		Shrapnel_SetTargetMode(1)
		events:PLAYER_TARGET_CHANGED()
	end
end

function events:PLAYER_ENTERING_WORLD()
	events:PLAYER_EQUIPMENT_CHANGED()
	events:PLAYER_SPECIALIZATION_CHANGED('player')
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
			if currentSpec == SPEC_MARKSMANSHIP then
				MultiShot:updateTargetsHit()
			elseif currentSpec == SPEC_SURVIVAL then
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
	if msg[1] == 'locked' then
		if msg[2] then
			Shrapnel.locked = msg[2] == 'on'
			UpdateDraggable()
		end
		print('Shrapnel - Locked: ' .. (Shrapnel.locked and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'snap' then
		if msg[2] then
			Shrapnel.snap = msg[2] == 'on'
		end
		print('Shrapnel - Snap to Blizzard combat resources frame: ' .. (Shrapnel.snap and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'scale' then
		if msg[2] == 'prev' then
			if msg[3] then
				Shrapnel.scale_previous = tonumber(msg[3]) or 0.7
				shrapnelPreviousPanel:SetScale(Shrapnel.scale_previous)
			end
			print('Shrapnel - Previous ability icon scale set to: |cFFFFD000' .. Shrapnel.scale_previous .. '|r times')
		elseif msg[2] == 'main' then
			if msg[3] then
				Shrapnel.scale_main = tonumber(msg[3]) or 1
				shrapnelPanel:SetScale(Shrapnel.scale_main)
			end
			print('Shrapnel - Main ability icon scale set to: |cFFFFD000' .. Shrapnel.scale_main .. '|r times')
		elseif msg[2] == 'cd' then
			if msg[3] then
				Shrapnel.scale_cooldown = tonumber(msg[3]) or 0.7
				shrapnelCooldownPanel:SetScale(Shrapnel.scale_cooldown)
			end
			print('Shrapnel - Cooldown ability icon scale set to: |cFFFFD000' .. Shrapnel.scale_cooldown .. '|r times')
		elseif msg[2] == 'trap' then
			if msg[3] then
				Shrapnel.scale_trap = tonumber(msg[3]) or 0.4
				shrapnelTrapPanel:SetScale(Shrapnel.scale_trap)
			end
			print('Shrapnel - Trap ability icon scale set to: |cFFFFD000' .. Shrapnel.scale_trap .. '|r times')
		elseif msg[2] == 'interrupt' then
			if msg[3] then
				Shrapnel.scale_interrupt = tonumber(msg[3]) or 0.4
				shrapnelInterruptPanel:SetScale(Shrapnel.scale_interrupt)
			end
			print('Shrapnel - Interrupt ability icon scale set to: |cFFFFD000' .. Shrapnel.scale_interrupt .. '|r times')
		elseif msg[2] == 'glow' then
			if msg[3] then
				Shrapnel.scale_glow = tonumber(msg[3]) or 1
				UpdateGlowColorAndScale()
			end
			print('Shrapnel - Action button glow scale set to: |cFFFFD000' .. Shrapnel.scale_glow .. '|r times')
		else
			print('Shrapnel - Default icon scale options are |cFFFFD000prev 0.7|r, |cFFFFD000main 1|r, |cFFFFD000cd 0.7|r, |cFFFFD000trap 0.7|r, |cFFFFD000interrupt 0.4|r, and |cFFFFD000glow 1|r')
		end
	elseif msg[1] == 'alpha' then
		if msg[2] then
			Shrapnel.alpha = max(min((tonumber(msg[2]) or 100), 100), 0) / 100
			UpdateAlpha()
		end
		print('Shrapnel - Icon transparency set to: |cFFFFD000' .. Shrapnel.alpha * 100 .. '%|r')
	elseif msg[1] == 'frequency' then
		if msg[2] then
			Shrapnel.frequency = tonumber(msg[2]) or 0.05
			UpdateHealthArray()
		end
		print('Shrapnel - Calculation frequency: Every |cFFFFD000' .. Shrapnel.frequency .. '|r seconds')
	elseif msg[1] == 'glow' then
		if msg[2] == 'main' then
			if msg[3] then
				Shrapnel.glow_main = msg[3] == 'on'
			end
			print('Shrapnel - Glowing ability buttons (main icon): ' .. (Shrapnel.glow_main and '|cFF00C000On' or '|cFFC00000Off'))
		elseif msg[2] == 'cd' then
			if msg[3] then
				Shrapnel.glow_cooldown = msg[3] == 'on'
			end
			print('Shrapnel - Glowing ability buttons (cooldown icon): ' .. (Shrapnel.glow_cooldown and '|cFF00C000On' or '|cFFC00000Off'))
		elseif msg[2] == 'trap' then
			if msg[3] then
				Shrapnel.glow_trap = msg[3] == 'on'
			end
			print('Shrapnel - Glowing ability buttons (trap icon): ' .. (Shrapnel.glow_trap and '|cFF00C000On' or '|cFFC00000Off'))
		elseif msg[2] == 'interrupt' then
			if msg[3] then
				Shrapnel.glow_interrupt = msg[3] == 'on'
			end
			print('Shrapnel - Glowing ability buttons (interrupt icon): ' .. (Shrapnel.glow_interrupt and '|cFF00C000On' or '|cFFC00000Off'))
		elseif msg[2] == 'blizzard' then
			if msg[3] then
				Shrapnel.glow_blizzard = msg[3] == 'on'
			end
			print('Shrapnel - Blizzard default proc glow: ' .. (Shrapnel.glow_blizzard and '|cFF00C000On' or '|cFFC00000Off'))
		elseif msg[2] == 'color' then
			if msg[5] then
				Shrapnel.glow_color.r = max(min(tonumber(msg[3]) or 0, 1), 0)
				Shrapnel.glow_color.g = max(min(tonumber(msg[4]) or 0, 1), 0)
				Shrapnel.glow_color.b = max(min(tonumber(msg[5]) or 0, 1), 0)
				UpdateGlowColorAndScale()
			end
			print('Shrapnel - Glow color:', '|cFFFF0000' .. Shrapnel.glow_color.r, '|cFF00FF00' .. Shrapnel.glow_color.g, '|cFF0000FF' .. Shrapnel.glow_color.b)
		else
			print('Shrapnel - Possible glow options are: |cFFFFD000main|r, |cFFFFD000cd|r, |cFFFFD000trap|r, |cFFFFD000interrupt|r, |cFFFFD000blizzard|r, and |cFFFFD000color')
		end
		UpdateGlows()
	elseif msg[1] == 'previous' then
		if msg[2] then
			Shrapnel.previous = msg[2] == 'on'
			events:PLAYER_TARGET_CHANGED()
		end
		print('Shrapnel - Previous ability icon: ' .. (Shrapnel.previous and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'always' then
		if msg[2] then
			Shrapnel.always_on = msg[2] == 'on'
			events:PLAYER_TARGET_CHANGED()
		end
		print('Shrapnel - Show the Shrapnel UI without a target: ' .. (Shrapnel.always_on and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'cd' then
		if msg[2] then
			Shrapnel.cooldown = msg[2] == 'on'
		end
		print('Shrapnel - Use Shrapnel for cooldown management: ' .. (Shrapnel.cooldown and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'gcd' then
		if msg[2] then
			Shrapnel.gcd = msg[2] == 'on'
			if not Shrapnel.gcd then
				shrapnelPanel.gcd:Hide()
			end
		end
		print('Shrapnel - Global cooldown swipe: ' .. (Shrapnel.gcd and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'dim' then
		if msg[2] then
			Shrapnel.dimmer = msg[2] == 'on'
			if not Shrapnel.dimmer then
				shrapnelPanel.dimmer:Hide()
			end
		end
		print('Shrapnel - Dim main ability icon when you don\'t have enough focus to use it: ' .. (Shrapnel.dimmer and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'miss' then
		if msg[2] then
			Shrapnel.miss_effect = msg[2] == 'on'
		end
		print('Shrapnel - Red border around previous ability when it fails to hit: ' .. (Shrapnel.miss_effect and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'aoe' then
		if msg[2] then
			Shrapnel.aoe = msg[2] == 'on'
			Shrapnel_SetTargetMode(1)
			UpdateDraggable()
		end
		print('Shrapnel - Allow clicking main ability icon to toggle amount of targets (disables moving): ' .. (Shrapnel.aoe and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'bossonly' then
		if msg[2] then
			Shrapnel.boss_only = msg[2] == 'on'
		end
		print('Shrapnel - Only use cooldowns on bosses: ' .. (Shrapnel.boss_only and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'hidespec' then
		if msg[2] then
			if msg[2] == "bm" then
				Shrapnel.hide_bm = not Shrapnel.hide_bm
				events:PLAYER_SPECIALIZATION_CHANGED('player')
				print('Shrapnel - Beast Mastery specialization: |cFFFFD000' .. (Shrapnel.hide_bm and '|cFFC00000Off' or '|cFF00C000On'))
			end
			if msg[2] == "mm" then
				Shrapnel.hide_mm = not Shrapnel.hide_mm
				events:PLAYER_SPECIALIZATION_CHANGED('player')
				print('Shrapnel - Marksmanship specialization: |cFFFFD000' .. (Shrapnel.hide_mm and '|cFFC00000Off' or '|cFF00C000On'))
			end
			if msg[2] == "sv" then
				Shrapnel.hide_sv = not Shrapnel.hide_sv
				events:PLAYER_SPECIALIZATION_CHANGED('player')
				print('Shrapnel - Survival specialization: |cFFFFD000' .. (Shrapnel.hide_sv and '|cFFC00000Off' or '|cFF00C000On'))
			end
		end
	elseif msg[1] == 'interrupt' then
		if msg[2] then
			Shrapnel.interrupt = msg[2] == 'on'
		end
		print('Shrapnel - Show an icon for interruptable spells: ' .. (Shrapnel.interrupt and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'trap' then
		if msg[2] then
			Shrapnel.trap = msg[2] == 'on'
		end
		print('Shrapnel - Show an icon for trap spells (survival): ' .. (Shrapnel.trap and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'st90' then
		if msg[2] then
			Shrapnel.single_90 = msg[2] == 'on'
		end
		print('Shrapnel - Include Barrage in single target: ' .. (Shrapnel.single_90 and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'auto' then
		if msg[2] then
			Shrapnel.auto_aoe = msg[2] == 'on'
		end
		print('Shrapnel - Automatically change target mode on Arcane Shot/Multi-Shot: ' .. (Shrapnel.auto_aoe and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'pot' then
		if msg[2] then
			Shrapnel.pot = msg[2] == 'on'
		end
		print('Shrapnel - Show Prolonged Power potions in cooldown UI: ' .. (Shrapnel.pot and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'reset' then
		shrapnelPanel:ClearAllPoints()
		shrapnelPanel:SetPoint('CENTER', 0, -169)
		shrapnelPreviousPanel:ClearAllPoints()
		shrapnelPreviousPanel:SetPoint('BOTTOMRIGHT', shrapnelPanel, 'BOTTOMLEFT', -10, -5)
		shrapnelCooldownPanel:ClearAllPoints()
		shrapnelCooldownPanel:SetPoint('BOTTOMLEFT', shrapnelPanel, 'BOTTOMRIGHT', 10, -5)
		shrapnelInterruptPanel:ClearAllPoints()
		shrapnelInterruptPanel:SetPoint('TOPLEFT', shrapnelPanel, 'TOPRIGHT', 16, 25)
		print('Shrapnel - Position has been reset to default')
	else
		print('Shrapnel (version: |cFFFFD000' .. GetAddOnMetadata('Shrapnel', 'Version') .. '|r) - Commands:')
		print('  /shrapnel locked |cFF00C000on|r/|cFFC00000off|r - lock the Shrapnel UI so that it can\'t be moved')
		print('  /shrapnel snap |cFF00C000on|r/|cFFC00000off|r - snap the Shrapnel UI to the Blizzard combat resources frame')
		print('  /shrapnel scale |cFFFFD000prev|r/|cFFFFD000main|r/|cFFFFD000cd|r/|cFFFFD000interrupt|r - adjust the scale of the Shrapnel UI icons')
		print('  /shrapnel alpha |cFFFFD000[percent]|r - adjust the transparency of the Shrapnel UI icons')
		print('  /shrapnel frequency |cFFFFD000[number]|r - set the calculation frequency (default is every 0.05 seconds)')
		print('  /shrapnel glow |cFFFFD000main|r/|cFFFFD000cd|r/|cFFFFD000interrupt|r/|cFFFFD000blizzard|r |cFF00C000on|r/|cFFC00000off|r - glowing ability buttons on action bars')
		print('  /shrapnel glow color |cFFF000000.0-1.0|r |cFF00FF000.1-1.0|r |cFF0000FF0.0-1.0|r - adjust the color of the ability button glow')
		print('  /shrapnel previous |cFF00C000on|r/|cFFC00000off|r - previous ability icon')
		print('  /shrapnel always |cFF00C000on|r/|cFFC00000off|r - show the Shrapnel UI without a target')
		print('  /shrapnel cd |cFF00C000on|r/|cFFC00000off|r - use Shrapnel for cooldown management')
		print('  /shrapnel gcd |cFF00C000on|r/|cFFC00000off|r - show global cooldown swipe on main ability icon')
		print('  /shrapnel dim |cFF00C000on|r/|cFFC00000off|r - dim main ability icon when you don\'t have enough focus to use it')
		print('  /shrapnel miss |cFF00C000on|r/|cFFC00000off|r - red border around previous ability when it fails to hit')
		print('  /shrapnel aoe |cFF00C000on|r/|cFFC00000off|r - allow clicking main ability icon to toggle amount of targets (disables moving)')
		print('  /shrapnel bossonly |cFF00C000on|r/|cFFC00000off|r - only use cooldowns on bosses')
		print('  /shrapnel hidespec |cFFFFD000bm|r/|cFFFFD000mm|r/|cFFFFD000sv|r - toggle disabling Shrapnel for specializations')
		print('  /shrapnel interrupt |cFF00C000on|r/|cFFC00000off|r - show an icon for interruptable spells')
		print('  /shrapnel trap |cFF00C000on|r/|cFFC00000off|r - show an icon for trap spells (survival)')
		print('  /shrapnel st90 |cFF00C000on|r/|cFFC00000off|r - include Barrage in single target')
		print('  /shrapnel auto |cFF00C000on|r/|cFFC00000off|r  - automatically change target mode on Arcane Shot/Multi-Shot')
		print('  /shrapnel pot |cFF00C000on|r/|cFFC00000off|r - show Prolonged Power potions in cooldown UI')
		print('  /shrapnel |cFFFFD000reset|r - reset the location of the Shrapnel UI to default')
		if Basic_Resources then
			print('For Basic Resources commands, please type |cFFFFD000/bres')
		end
	end
end