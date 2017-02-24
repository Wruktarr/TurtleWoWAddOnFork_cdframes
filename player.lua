module 'cooldowns.player'

include 'T'
include 'cooldowns'

local cooldowns_frame = require 'cooldowns.frame'

local last_used

function SETUP()
	cooldowns_settings.PLAYER = cooldowns_settings.PLAYER or {}
	M.frame = cooldowns_frame.new('Player Cooldowns', {.2, .8, .2}, cooldowns_settings.PLAYER)
	do
		local frame = CreateFrame('Frame')
		frame:SetScript('OnEvent', function() _M[event]() end)
		frame:RegisterEvent('BAG_UPDATE_COOLDOWN')
		frame:RegisterEvent('SPELL_UPDATE_COOLDOWN')
		frame:RegisterEvent('SPELLCAST_START')
		frame:RegisterEvent('SPELLCAST_STOP')
		frame:RegisterEvent('CHAT_MSG_SPELL_FAILED_LOCALPLAYER')
	end
	BAG_UPDATE_COOLDOWN()
	SPELL_UPDATE_COOLDOWN()
end

function BAG_UPDATE_COOLDOWN()
	for bag = 0, 4 do
		if GetBagName(bag) then
			for slot = 1, GetContainerNumSlots(bag) do
				local started, duration, enabled = GetContainerItemCooldown(bag, slot)
				if enabled == 1 then
					local name = link_name(GetContainerItemLink(bag, slot))
					if duration > 3 and duration <= 1800 and GetItemInfo(6948) ~= name then
						start_cd(
							name,
							GetContainerItemInfo(bag, slot),
							started,
							duration
						)
					elseif duration == 0 then
						stop_cd(started)
					end
				end
			end
		end
	end
	for slot = 0, 19 do
		local started, duration, enabled = GetInventoryItemCooldown('player', slot)
		if enabled == 1 then
			local name = link_name(GetInventoryItemLink('player', slot))
			if duration > 3 and duration <= 1800 then
				start_cd(
					name,
					GetInventoryItemTexture('player', slot),
					started,
					duration
				)
			elseif duration == 0 then
				stop_cd(started)
			end
		end
	end
end

function SPELL_UPDATE_COOLDOWN()
	local _, _, offset, spell_count = GetSpellTabInfo(GetNumSpellTabs())
	local total_spells = offset + spell_count
	for id = 1, total_spells do
		local started, duration, enabled = GetSpellCooldown(id, BOOKTYPE_SPELL)
		local name = GetSpellName(id, BOOKTYPE_SPELL)
		if enabled == 1 and duration > 2.5 then
			start_cd(
				name,
				GetSpellTexture(id, BOOKTYPE_SPELL),
				started,
				duration
			)
		elseif duration == 0 then
			stop_cd(name)
		end
	end
	for id = 1, HasPetSpells() or 0 do
		local started, duration, enabled = GetSpellCooldown(id, BOOKTYPE_PET)
		local name = GetSpellName(id, BOOKTYPE_PET)
		if enabled == 1 and duration > 2.5 then
			start_cd(
				name,
				GetSpellTexture(id, BOOKTYPE_PET),
				started,
				duration,
				true
			)
		elseif duration == 0 then
			stop_cd(name)
		end
	end
end

do
	local cooldowns = {}
	function start_cd(name, texture, started, duration, pet)
		if cooldowns_settings.used and not pet and name ~= last_used then return end
		if cooldowns[name] then frame:CancelCD(cooldowns[name]) end
		cooldowns[name] = frame:StartCD(name, '', texture, started, duration)
	end
	function stop_cd(name)
		if cooldowns[name] then frame:CancelCD(cooldowns[name]) end
	end
end

function link_name(link)
	for name in string.gfind(link, '|Hitem:%d+:%d+:%d+:%d+|h[[]([^]]+)[]]|h') do return name end
end

do
	local cast

	function SPELLCAST_START()
		cast = arg1
	end
	function SPELLCAST_STOP()
		cast = nil
	end

	function CHAT_MSG_SPELL_FAILED_LOCALPLAYER()
		for name, reason in string.gfind(arg1, 'You fail to %a+ (.*): (.*)') do
			if name == cast and reason ~= 'Another action is in progress.' then
				cast = nil
			end
		end
	end

	do
		local orig = UseContainerItem
		function _G.UseContainerItem(...)
			if not cast then
				last_used = link_name(GetContainerItemLink(unpack(arg)) or '')
			end
			return orig(unpack(arg))
		end
	end

	do
		local orig = UseInventoryItem
		function _G.UseInventoryItem(...)
			if not cast then
				last_used = link_name(GetInventoryItemLink('player', arg[1]) or '')
			end
			return orig(unpack(arg))
		end
	end

	do
		local orig = CastSpellByName
		function _G.CastSpellByName(...)
			if not cast then
				last_used = arg[1]
			end
			return orig(unpack(arg))
		end
	end

	do
		local orig = CastSpell
		function _G.CastSpell(...)
			if not cast then
				last_used = GetSpellName(unpack(arg))
			end
			return orig(unpack(arg))
		end
	end

	do
		local orig = UseAction
		function _G.UseAction(...)
			if not cast and HasAction(arg[1]) and not GetActionText(arg[1]) then
				cooldowns_Tooltip:SetOwner(UIParent, 'ANCHOR_NONE')
				cooldowns_Tooltip:SetAction(arg[1])
				last_used = cooldowns_TooltipTextLeft1:GetText()
			end
			return orig(unpack(arg))
		end
	end
end