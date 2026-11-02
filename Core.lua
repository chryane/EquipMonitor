--[[ Core.lua - 存档 / 物品与法术信息 / 装备扫描 / 事件
	 目标客户端：泰坦重铸 3.80.2，接口直调、不做存在性兜底。
]]

local ADDON_NAME, ns = ...

local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- ★ select(5) 就是 textureID（数字），SetTexture 直接吃，不用转路径
function ns.ItemIcon(itemID)
	return select(5, C_Item.GetItemInfoInstant(itemID)) or DEFAULT_ICON
end

function ns.SpellIcon(spellID)
	return C_Spell.GetSpellTexture(spellID) or DEFAULT_ICON
end

ns.ICON_ITEM, ns.ICON_SPELL = "item", "spell"

-- ★ 缺 iconSource 字段（老存档）= 物品图标
function ns.EntryIcon(e)
	if e.iconSource == ns.ICON_SPELL then return ns.SpellIcon(e.spellID) end
	return ns.ItemIcon(e.itemID)
end

function ns.ItemName(itemID)
	return C_Item.GetItemNameByID(itemID) or (ns.L.UnknownItem .. " " .. itemID)
end

function ns.SpellName(spellID)
	return C_Spell.GetSpellName(spellID) or (ns.L.UnknownSpell .. " " .. spellID)
end

function ns.ItemLabel(e)
	return e.itemName or ns.ItemName(e.itemID)
end

function ns.SpellLabel(e)
	return e.spellName or ns.SpellName(e.spellID)
end

-- ★ 一格要的三件事（有没有 / 倒计时 / 层数）全从它派生 ⇒ 别为同一个法术查三遍
function ns.PlayerAura(spellID)
	return C_UnitAuras.GetPlayerAuraBySpellID(spellID)
end

-- ★ 只返回第一个命中：两枚同名戒指永远回前一个
function ns.EquippedSlotOf(itemID)
	for slot = 1, 19 do
		if GetInventoryItemID("player", slot) == itemID then return slot end
	end
end

-- 两个时间都是 GetTime() 基准。★ 走完的那对值客户端不会清成 0，得自己判
function ns.ItemCooldown(slot)
	local start, duration = GetInventoryItemCooldown("player", slot)
	if not duration or duration <= 0 then return end
	if start + duration <= GetTime() then return end
	return start, duration
end

ns.TRINKET_A, ns.TRINKET_B = 13, 14

-- ★ 必须是全局名（宏跑在全局环境里）；★ 战斗中不做
function EquipMonitor_SwapTrinkets()
	if InCombatLockdown() then return end
	ClearCursor()
	PickupInventoryItem(ns.TRINKET_A)
	PickupInventoryItem(ns.TRINKET_B)
	PickupInventoryItem(ns.TRINKET_A)
	ClearCursor()
end

local function Changed()
	ns.Bar:Update()
	ns.Options:ReloadIfOpen()
end

-- 只留这 10 个字段：导入按这一份走，多出来的键（老存档残留）不往存档里带
function ns.CopyEntry(e)
	return {
		itemID = e.itemID, spellID = e.spellID,
		itemName = e.itemName, spellName = e.spellName,
		duration = e.duration, cooldown = e.cooldown,
		enabled = e.enabled, clickable = e.clickable,
		procOnly = e.procOnly, iconSource = e.iconSource,
	}
end

function ns:Add(entry)
	local entries = self.db.entries
	entries[#entries + 1] = entry
	Changed()
end

function ns:Save(index, entry)
	self.db.entries[index] = entry
	Changed()
end

function ns:Remove(index)
	table.remove(self.db.entries, index)
	Changed()
end

-- ★ 挪的是数组顺序 ⇒ 快捷条常驻段跟着挪；触发条目在列表里挪了、条上不变
function ns:Move(index, delta)
	local entries = self.db.entries
	local j = index + delta
	if not (entries[index] and entries[j]) then return end
	entries[index], entries[j] = entries[j], entries[index]
	Changed()
end

-- ★ 没缓存名字的物品要主动要一次；GetItemInfo 与 RequestLoadItemDataByID 都得调（后者单独调没反应）
function ns.RequestItemData(entries)
	for i = 1, #entries do
		local id = entries[i].itemID
		if id and not C_Item.GetItemNameByID(id) then
			C_Item.GetItemInfo(id)
			C_Item.RequestLoadItemDataByID(id)
		end
	end
end

-- ★ rule：skip = 已存在就跳过 / overwrite = 用导入的替换 / new = 一律当新的一条（同ID也追加）；
--   返回三个计数给界面显示结果
function ns:Import(list, rule)
	local entries = self.db.entries
	local at = {}
	for i = 1, #entries do at[entries[i].itemID] = i end
	local added, skipped, replaced = 0, 0, 0
	for i = 1, #list do
		local e = list[i]
		local slot = at[e.itemID]
		if not slot or rule == "new" then
			entries[#entries + 1] = ns.CopyEntry(e)
			at[e.itemID] = #entries
			added = added + 1
		elseif rule == "overwrite" then
			entries[slot] = ns.CopyEntry(e)
			replaced = replaced + 1
		else
			skipped = skipped + 1
		end
	end
	if added + replaced > 0 then
		ns.RequestItemData(list)
		Changed()
	end
	return added, skipped, replaced
end

-- 存档缺省值。★ 只在 db[k] == nil 时才填 ⇒ 改这里对已有存档无效
local DEFAULTS = {
	enabled = true,
	locked = false,
	swapTrinkets = false,
	tooltip = true,
	slotSize = 40,
	gap = 1,
	fontSize = 16,
}

function ns:InitDB()
	if type(EquipMonitorDB) ~= "table" then EquipMonitorDB = {} end
	local db = EquipMonitorDB
	for k, v in pairs(DEFAULTS) do
		if db[k] == nil then db[k] = v end
	end
	if type(db.entries) ~= "table" then db.entries = {} end
	if type(db.icd) ~= "table" then db.icd = {} end
	-- ★ Slider:SetValue 不吸附步长 ⇒ 存档里手改过的浮点会让 thumb 停在半格，读档统一取整
	db.slotSize = math.floor(db.slotSize + 0.5)
	db.gap = math.floor(db.gap + 0.5)
	db.fontSize = math.floor(db.fontSize + 0.5)
	self.db = db
end

function ns:InitEvents()
	local f = CreateFrame("Frame")
	f:SetScript("OnEvent", function(_, event, arg1, arg2)
		if event == "GET_ITEM_INFO_RECEIVED" then
			ns.Options:ItemDataReady()
		elseif event == "UNIT_AURA" then
			ns.Bar:AuraChanged(arg2)
		elseif event == "PLAYER_EQUIPMENT_CHANGED" then
			ns.Bar:EquipChanged(arg1)
		elseif event == "BAG_UPDATE_COOLDOWN" then
			ns.Bar:ItemCooldownChanged()
		elseif event == "PLAYER_ENTERING_WORLD" then
			-- arg1 = 登录、arg2 = 重载界面；两个都是 false 才是过图（传送门 / 进副本）—— 过图只重画
			ns.Bar:EnterWorld(arg1 or arg2)
		else
			ns.Bar:Update()
		end
	end)
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	f:RegisterEvent("BAG_UPDATE_COOLDOWN")
	f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	-- ★ 必须做单元限定：不限定则小队 / 团队 / 目标 / 宠物 / 姓名板的光环变化全推过来
	f:RegisterUnitEvent("UNIT_AURA", "player")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function ns:OnLoad()
	self:InitDB()
	-- 登录补一次：导入来的条目没存名字，缓存一空就又变「未知物品」
	self:RequestItemData(self.db.entries)
	self.Bar:Create()
	self.Bar:Update()
	self:InitEvents()
end

-- 现场自证：/emon debug（本客户端没有 debug 库）—— 强制 GC 后取存活量 + 数一遍运行时容器，只读
local function Count(t)
	local c = 0
	for _ in pairs(t) do c = c + 1 end
	return c
end

function ns:Debug()
	local b = self.Bar
	collectgarbage("collect")
	UpdateAddOnMemoryUsage()
	print(string.format("EquipMonitor %.1fKB / Lua %.0fKB", GetAddOnMemoryUsage(ADDON_NAME), collectgarbage("count")))
	print(string.format("entries %d worn %d | auraVal %d auraGen %d auraUp %d auraAt %d icd %d db.icd %d ins %d set %d",
		#self.db.entries, #b.worn, Count(b.auraVal), Count(b.auraGen), Count(b.auraUp), Count(b.auraAt),
		Count(b.icd), Count(self.db.icd), Count(b.auraIns), Count(b.spellSet)))
end

SLASH_EQUIPMONITOR1 = "/emon"
SLASH_EQUIPMONITOR2 = "/equipmonitor"
SlashCmdList["EQUIPMONITOR"] = function(msg)
	if msg == "debug" then ns:Debug() else ns.Options:Open() end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
	if name == ADDON_NAME then
		self:UnregisterEvent("ADDON_LOADED")
		ns:OnLoad()
	end
end)
