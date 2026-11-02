--[[ Bar.lua - 装备监控快捷条
	 ★ 战斗中 secure 帧的 SetPoint/SetSize/Show/Hide/SetAttribute 一律被拦 ⇒ 几何与宏只在脱战落地（Layout），
	   战斗中只改贴图内容与 btn.entry。★ 别给 secure 格子挂 OnClick/OnMouseUp（会顶掉 SecureActionButton_OnClick）。
]]

local _, ns = ...

local Bar = {}
ns.Bar = Bar

local function EdgeOf(w)
	return math.floor(w / 12 + 0.5)
end

-- 这张图四周没有透明留白：别裁别缩，裁了亮边就没了
local FRAME_TEX = "Interface\\AddOns\\EquipMonitor\\Textures\\UI-Frame-Button.tga"

local GLOW_TEX = "Interface\\SpellActivationOverlay\\IconAlert"
local GLOW_U0, GLOW_U1, GLOW_V0, GLOW_V1 = 0.00781250, 0.50781250, 0.27734375, 0.52734375
local GLOW_INSET = 0.06
local GLOW_OUT = 3
local function CropTC(u0, u1, v0, v1, f)
	local cu, hu = (u0 + u1) / 2, (u1 - u0) * (1 - 2 * f) / 2
	local cv, hv = (v0 + v1) / 2, (v1 - v0) * (1 - 2 * f) / 2
	return cu - hu, cu + hu, cv - hv, cv + hv
end
local GLOW_TC = { CropTC(GLOW_U0, GLOW_U1, GLOW_V0, GLOW_V1, GLOW_INSET) }
local ANTS_TEX = "Interface\\SpellActivationOverlay\\IconAlertAnts"
local ANTS_ROWS, ANTS_COLS, ANTS_FRAMES = 5, 5, 22
local ANTS_CELL = 48	-- 不是 atlas：FlipBook 推不出格子尺寸，必须自己给全
local ANTS_CYCLE = 0.9
local GLOW_DIM, GLOW_LIT = 0.85, 1
local GLOW_PERIOD = 1.2

local GRIP_W, GRIP_HIT_PAD = 5, 8	-- 命中区只往左扩：往右会抢格子的点击区
local GRIP_INSET = 2
local GRIP_GAP = 1	-- 固定 1px，不跟「图标间距」滑条走
local GRIP_BG_ALPHA = 0.55
local SLOT_MAX = 16
local STACK_FONT, STACK_INSET = 10, 2	-- 固定 10 号，不跟「图标计时文字大小」滑条走

local SWAP_MACRO = "/run EquipMonitor_SwapTrinkets()"

local function Has(list, e)
	for i = 1, #list do
		if list[i] == e then return true end
	end
end

local function Resident(e)
	return e.enabled ~= false and not e.procOnly and ns.EquippedSlotOf(e.itemID)
end

-- 条目被替换 / 删掉后，旧那张表还挂在这三张映射上（每次保存 / 覆盖导入都换一张新表）⇒ 顺手摘掉
local function PruneStaleKeys(map, entries)
	for e in pairs(map) do
		if not Has(entries, e) then map[e] = nil end
	end
end

local function OnTrinket(slot)
	return slot == ns.TRINKET_A or slot == ns.TRINKET_B
end

-- 饰品槽没勾「点击施法」的不问 API：只有那个部位会出现"这件装备自己没被用、冷却却来了"（共用冷却）
local function CanReadApi(e, slot)
	return e.clickable or not OnTrinket(slot)
end

-- 同一个法术一代只查一次（每调一次就现造一张光环表）；★ 换代只在 AuraChanged 做，别的重画一律复用
local function Aura(e)
	local id = e and e.spellID
	if not id then return nil end
	if Bar.auraGen[id] ~= Bar.gen then
		Bar.auraGen[id] = Bar.gen
		Bar.auraVal[id] = ns.PlayerAura(id)
	end
	return Bar.auraVal[id]
end

-- 面层必须走 BACKGROUND subLevel 1：BORDER 在 ARTWORK 之上，会把图标蒙上一层
local function AddSquareLayers(f)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetTexture(FRAME_TEX)
	f.bg:SetVertexColor(0, 0, 0)
	f.bg:SetAllPoints()

	f.border = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.border:SetTexture(FRAME_TEX)
	f.border:SetAllPoints()
end

function Bar:ApplyMetrics()
	local w, gap = ns.db.slotSize, ns.db.gap
	local edge, pitch, antsW = EdgeOf(w), w + gap, w + GLOW_OUT * 2
	for i = 1, SLOT_MAX do
		local btn = self.slots[i]
		btn:SetSize(w, w)
		btn:SetPoint("LEFT", self.frame, "LEFT", (i - 1) * pitch, 0)
		btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", edge, -edge)
		btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -edge, edge)
		btn.glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -GLOW_OUT, GLOW_OUT)
		btn.glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", GLOW_OUT, -GLOW_OUT)
		btn.ants:SetSize(antsW, antsW)
	end
	self.frame:SetSize(1, w)
	self.grip:SetSize(GRIP_W, w - GRIP_INSET)
	self.grip:SetPoint("RIGHT", self.frame, "LEFT", -GRIP_GAP, 0)
end

function Bar:CreateSlot(index)
	local btn = CreateFrame("Button", nil, self.frame, "SecureActionButtonTemplate")
	AddSquareLayers(btn)
	btn.icon = btn:CreateTexture(nil, "ARTWORK")
	-- 发光走"喂不喂贴图"开关、不走 Show/Hide：触发的图标是战斗中随时冒出来的，显隐那条路不能碰
	btn.glow = btn:CreateTexture(nil, "OVERLAY")
	btn.glow:SetTexture(GLOW_TEX)
	btn.glow:SetTexCoord(GLOW_TC[1], GLOW_TC[2], GLOW_TC[3], GLOW_TC[4])

	btn.ants = btn:CreateTexture(nil, "OVERLAY")
	btn.ants:SetTexture(ANTS_TEX)
	btn.ants:SetPoint("CENTER")
	-- 动画组一播就每帧动 ⇒ 建出来必须是停的，开关只在 Paint 那一处下发
	local breath = btn:CreateAnimationGroup()
	breath:SetLooping("BOUNCE")
	local fade = breath:CreateAnimation("Alpha")
	fade:SetTarget(btn.glow)
	fade:SetFromAlpha(GLOW_DIM)
	fade:SetToAlpha(GLOW_LIT)
	fade:SetDuration(GLOW_PERIOD)
	fade:SetSmoothing("IN_OUT")
	btn.breath = breath
	local spin = btn:CreateAnimationGroup()
	spin:SetLooping("REPEAT")
	local march = spin:CreateAnimation("FlipBook")
	march:SetTarget(btn.ants)
	march:SetFlipBookRows(ANTS_ROWS)
	march:SetFlipBookColumns(ANTS_COLS)
	march:SetFlipBookFrames(ANTS_FRAMES)
	march:SetFlipBookFrameWidth(ANTS_CELL)
	march:SetFlipBookFrameHeight(ANTS_CELL)
	march:SetDuration(ANTS_CYCLE)
	btn.spin = spin
	-- ★ 留 nil：首次重画必然走一趟「不亮」，把创建时喂上的发光贴图清掉
	-- 必须建在发光那两层之后（同 drawLayer 按创建先后画）
	btn.stacks = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	btn.stacks:SetFontHeight(STACK_FONT)
	btn.stacks:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", -STACK_INSET, STACK_INSET)
	btn.cdBuff = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
	btn.cdIcd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
	for _, cd in ipairs({ btn.cdBuff, btn.cdIcd }) do
		cd:SetAllPoints(btn.icon)
		cd:SetDrawEdge(false)
		cd:SetDrawBling(false)
		cd:SetDrawSwipe(false)
		-- 模板默认 hidden；显隐全由 SetCooldown/Clear 控 ⇒ 战斗中一次显隐都不做
		cd:Show()
	end
	btn.cdIcd:SetScript("OnCooldownDone", function()
		-- 必须走 ClearIcd：存档那条一起删，否则重载后会把走完的段画回来
		self:ClearIcd(btn.entry)
		self:Refresh()
	end)
	btn:SetFrameLevel(self.frame:GetFrameLevel() + 2)
	btn:RegisterForClicks("AnyUp", "LeftButtonDown", "RightButtonDown")
	btn:SetScript("OnEnter", function(f)
		if f.entry and ns.db.enabled ~= false and ns.db.tooltip then self:ShowTip(f) end
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.slots[index] = btn
end

function Bar:BindSlot(btn, e, slot)
	btn.entry = e
	local macro = slot and e.clickable and ("/use " .. slot) or nil
	btn:SetAttribute("*type1", macro and "macro" or nil)
	btn:SetAttribute("*macrotext1", macro)
	local swap = ns.db.swapTrinkets and OnTrinket(slot)
	btn:SetAttribute("shift-type2", swap and "macro" or nil)
	btn:SetAttribute("shift-macrotext2", swap and SWAP_MACRO or nil)
end

-- 触发顺序 = 触发先后（与条目顺序无关）；worn 里全是「启用 + 穿着中的」，脱下的 / 删掉的自动出局
function Bar:UpdateProcOrder()
	local t, worn = self.procOrder, self.worn
	for i = #t, 1, -1 do
		local e = t[i]
		if not (e.procOnly and Has(worn, e) and Aura(e) ~= nil) then table.remove(t, i) end
	end
	for i = 1, #worn do
		local e = worn[i]
		if e.procOnly and Aura(e) ~= nil and not Has(t, e) then t[#t + 1] = e end
	end
end

-- ★ 起 / 清都得走这两个函数（只写内存那份，/reload 后被动 ICD 就接不上了）；存档记的是到期时刻、
--   基准 GetServerTime()（GetTime() 重登会归零），键 = 法术ID
function Bar:SetIcd(e, start, len)
	local c = self.icd[e]
	if c then c.start, c.len = start, len else self.icd[e] = { start = start, len = len } end
	if e.spellID then ns.db.icd[e.spellID] = GetServerTime() + (start + len - GetTime()) end
end

-- ★ 空位的 cdIcd:OnCooldownDone 也会走到这里（btn.entry 是 nil）⇒ guard 不能删
function Bar:ClearIcd(e)
	if not e then return end
	self.icd[e] = nil
	if e.spellID then ns.db.icd[e.spellID] = nil end
end

-- 一格此刻该画哪段冷却（两条来源，读到哪个用哪个）：① API 读得到就按它；② 读不到（被动 ICD）才按
-- 「触发时刻 + 此刻 + 条目配的冷却」自己算。★ 返回 nil = 都没读到，调用方别据此清已有记录
function Bar:CdOf(e)
	local slot = Resident(e)
	local start, len
	if slot and CanReadApi(e, slot) then start, len = ns.ItemCooldown(slot) end
	if start then return start, len end
	local trig = self.auraAt[e]
	if trig and (e.cooldown or 0) > GetTime() - trig then return trig, e.cooldown end
end

-- 起点 = 法术触发那一刻 ⇒ 触发时刻必须在增益还在身上时记下来（光环一没就查不到了）
function Bar:UpdateIcd()
	local now = GetTime()
	for _, e in ipairs(self.worn) do
		local aura = Aura(e)
		local up, was = aura ~= nil, self.auraUp[e]
		if up then
			local dur = aura.duration
			if dur and dur > 0 then
				self.auraAt[e] = aura.expirationTime - dur
			elseif not was then
				self.auraAt[e] = now
			end
		end
		if up and not was then
			self:ClearIcd(e)
		elseif was and not up then
			local start, len = self:CdOf(e)
			if start then self:SetIcd(e, start, len) end
		end
		self.auraUp[e] = up
	end
end

function Bar:IcdOf(e)
	local c = self.icd[e]
	if c and GetTime() - c.start < c.len then return c.start, c.len end
end

-- ★ 起点用"现在"（换装 = 服务端刚把 ICD 推满）；★ 只针对常驻条目；★ 增益在身时整条让位
function Bar:UpdateEquipIcd(e, slot)
	if Aura(e) then self:ClearIcd(e) return end
	local start, len = ns.ItemCooldown(slot)
	if not start and not e.clickable and (e.cooldown or 0) > 0 then
		start, len = GetTime(), e.cooldown
	end
	if start then self:SetIcd(e, start, len) else self:ClearIcd(e) end
end

function Bar:EquipChanged(slot)
	for _, e in ipairs(ns.db.entries) do
		if Resident(e) == slot then self:UpdateEquipIcd(e, slot) end
	end
	self:Update()
end

-- 物品冷却一变就重读（装备栏右键 / 动作条 / 快捷条点击都走这条）；★ 事件不说哪一格 ⇒ 全扫一遍；
-- ★ 只认 API（被动 ICD 归 UpdateIcd）；★ 读不到不主动清
function Bar:ReadItemIcd()
	for _, e in ipairs(ns.db.entries) do
		local slot = Resident(e)
		if slot and CanReadApi(e, slot) and not Aura(e) then
			local start, len = ns.ItemCooldown(slot)
			if start then self:SetIcd(e, start, len) end
		end
	end
end

-- ★ 先问 API（物品冷却重读一次即可，物品对象不随 /reload 重建），读不到才看存档那份；★ 增益在身不接
function Bar:RestoreIcd()
	for _, e in ipairs(ns.db.entries) do
		local slot, start, len = Resident(e), nil, nil
		if slot and not Aura(e) then
			start, len = ns.ItemCooldown(slot)
			if not start then
				local rest = (ns.db.icd[e.spellID] or 0) - GetServerTime()
				if rest > 0 then start, len = GetTime(), rest end
			end
		end
		if start then self:SetIcd(e, start, len) else self:ClearIcd(e) end
	end
	local alive = {}
	for _, e in ipairs(ns.db.entries) do alive[e.spellID] = true end
	for spellID in pairs(ns.db.icd) do
		if not alive[spellID] then ns.db.icd[spellID] = nil end
	end
end

-- ★★ 过图（fresh 为假）只重画、记录一个字都不动：那一刻装备表可能还没填好，重排会把 resident 数成 0
--   把整条清空、RestoreIcd 会把还在冷却的条目当"装备已脱下"，而两条都没有事件替它恢复
function Bar:EnterWorld(fresh)
	self.flushQueued = false	-- 过图 / 重载可能把排着的那趟定时器丢了，丢了就再也不排新的
	if fresh then
		self:RestoreIcd()
		self:Update()
	else
		self:Repaint()
	end
end

-- ★★ 开口先比签名：全一样就一个 API 都不调；签名表复用同一张 btn.paint，否则省下的开销又用分配还回去
local function Paint(btn, e)
	local aura = Aura(e)
	local icdStart, icdLen
	if e then icdStart, icdLen = Bar:IcdOf(e) end
	local tex = e and ns.EntryIcon(e)
	local v = tex and 1 or 0
	local aStart, aDur
	if aura and aura.duration and aura.duration > 0 then
		aStart, aDur = aura.expirationTime - aura.duration, aura.duration
	end
	local up = aura ~= nil
	local stacks = aura and aura.applications

	local s = btn.paint or {}
	if s.e == e and s.tex == tex and s.up == up and s.app == stacks
		and s.aStart == aStart and s.aDur == aDur and s.iStart == icdStart and s.iLen == icdLen
		and s.font == ns.db.fontSize then
		return v
	end

	s.e, s.tex, s.up, s.app = e, tex, up, stacks
	s.aStart, s.aDur, s.iStart, s.iLen, s.font = aStart, aDur, icdStart, icdLen, ns.db.fontSize
	btn.paint = s

	-- 逐项只下发"真的变了"的那几样：触发一次要来回重画两遍（亮起 / 熄灭），
	-- 同一张图 / 同一组坐标重设两遍纯属白跑 C
	if btn.tex ~= tex then
		btn.tex = tex
		btn.icon:SetTexture(tex)
	end
	if btn.desat ~= (icdStart ~= nil) then
		btn.desat = icdStart ~= nil
		btn.icon:SetDesaturated(btn.desat)	-- 冷却期整格褪色
	end
	if btn.fill ~= v then
		btn.fill = v
		btn.bg:SetTexCoord(0, v, 0, v)
		btn.border:SetTexCoord(0, v, 0, v)
	end

	-- 亮 / 不亮只在翻转时换贴图并起停动画：不亮时不播（贴图是空的，播了看不见却每帧在动），
	-- 同图重复 SetTexture 也是白跑一趟 C。全插件只有这一处下发 Play/Stop
	if btn.animOn ~= up then
		btn.animOn = up
		btn.glow:SetTexture(up and GLOW_TEX or nil)
		btn.ants:SetTexture(up and ANTS_TEX or nil)
		if up then
			btn.breath:Play()
			btn.spin:Play()
		else
			btn.breath:Stop()
			btn.spin:Stop()
		end
	end

	-- ★ 冷却帧只在「哪一段」真变了才喂：SetCooldown / Clear 每次都会重建刷条与倒计时，
	--   而触发这一路每来回一次就会重画两遍（亮起 / 熄灭），同一段喂两遍纯属白做
	if aStart then
		if btn.aStart ~= aStart or btn.aDur ~= aDur then
			btn.aStart, btn.aDur = aStart, aDur
			btn.cdBuff:SetCooldown(aStart, aDur)
			btn.aFont = nil	-- SetCooldown 会把数字字号重置回模板默认
		end
	elseif btn.aStart then
		btn.aStart, btn.aDur = nil, nil
		btn.cdBuff:Clear()
	end
	if icdStart then
		if btn.iStart ~= icdStart or btn.iLen ~= icdLen then
			btn.iStart, btn.iLen = icdStart, icdLen
			btn.cdIcd:SetCooldown(icdStart, icdLen)
			btn.cdIcd:GetCountdownFontString():SetTextColor(1, 0.1, 0.1)
			btn.iFont = nil
		end
	elseif btn.iStart then
		btn.iStart, btn.iLen = nil, nil
		btn.cdIcd:Clear()
	end
	-- 字体串归引擎所有、喂冷却之后才取；字号没变就不用再设一遍（每次都设 = 每次重排字形）
	if btn.aFont ~= ns.db.fontSize then
		btn.aFont = ns.db.fontSize
		btn.cdBuff:GetCountdownFontString():SetFontHeight(ns.db.fontSize)
	end
	if btn.iFont ~= ns.db.fontSize then
		btn.iFont = ns.db.fontSize
		btn.cdIcd:GetCountdownFontString():SetFontHeight(ns.db.fontSize)
	end
	-- 用空串而非 Show/Hide；★ 门槛必须 > 1（不叠层的增益 applications 也是 1，跟"叠 1 层"分不开）
	if stacks and stacks > 1 then
		if btn.stackNum ~= stacks then
			btn.stackNum = stacks
			btn.stacks:SetText(tostring(stacks))
		end
	elseif btn.stackNum then
		btn.stackNum = nil
		btn.stacks:SetText("")
	end
	return v
end

-- ★ 这里不换代：光环缓存只在 RefreshAura 里换代（那一处才现查），其余重画直接复用 ——
--   每次重画都现查一遍，站着不动也在按重画次数造垃圾（GetPlayerAuraBySpellID 每次新建一张表）
function Bar:Refresh()
	self:UpdateIcd()
	self:UpdateProcOrder()
	-- 不勾「启用」= 全部刷成空格子；★ 属性不动（解绑只能等脱战 Layout）
	if ns.db.enabled == false then
		for i = 1, SLOT_MAX do
			Paint(self.slots[i], nil)
		end
		self.live = 0
		return
	end
	local live = 0
	for i = 1, self.resident do
		local btn = self.slots[i]
		live = live + Paint(btn, btn.entry)
	end
	for i = self.resident + 1, SLOT_MAX do
		local btn = self.slots[i]
		btn.entry = self.procOrder[i - self.resident]
		live = live + Paint(btn, btn.entry)
	end
	self.live = live
end

-- 高频事件（增益 / 过图）只重画：几何与宏不动；抓手显隐跟着 live，战斗中留到脱战那次重排补
-- ★ 动手画之前先把待办落地（flag 已清 ⇒ 定时器那趟空转，不会重入）
function Bar:Repaint()
	self:ApplyPending()
	self:Refresh()
	if not InCombatLockdown() then self:UpdateGrip() end
end

function Bar:Layout()
	self:ApplyMetrics()
	-- 「关注集合」= 监控列表 ∩ 身上穿着的（最多 19 条，实际更少）：未装备的条目不可能上条，
	-- 它绑的法术也就不该管（上图标、查光环、倒计时、触发顺序都只看这一份）。
	-- ★ 只有装备变更才会改它，而装备变更走的正是这里（战斗中换不了装备 ⇒ 不会漏）
	local entries, worn, n = ns.db.entries, self.worn, 0
	for k = #worn, 1, -1 do worn[k] = nil end
	-- 一次扫完装备栏就够（逐条目去查是 #entries × 19 次调用）；同 ID 取靠前那格
	local equipped = {}
	for slot = 1, 19 do
		local id = GetInventoryItemID("player", slot)
		if id and not equipped[id] then equipped[id] = slot end
	end
	local on = ns.db.enabled ~= false
	for i = 1, #entries do
		local e = entries[i]
		local slot = e.enabled ~= false and equipped[e.itemID]
		if slot then
			worn[#worn + 1] = e
			if on and not e.procOnly and n < SLOT_MAX then
				n = n + 1
				self:BindSlot(self.slots[n], e, slot)
			end
		end
	end
	PruneStaleKeys(self.auraUp, entries)
	PruneStaleKeys(self.auraAt, entries)
	PruneStaleKeys(self.icd, entries)
	self.resident = n
	for i = n + 1, SLOT_MAX do
		self:BindSlot(self.slots[i], nil)
	end
	self:Repaint()
end

-- 只重排几何，不碰宏（重写 16 格 secure 属性是白费）
function Bar:Reflow()
	if not InCombatLockdown() then self:ApplyMetrics() end
	self:Repaint()
end

-- ★ 待办先落地：否则这一帧画的是旧光环（战斗里只能改内容，脱战才动几何与宏）
function Bar:Update()
	self:ApplyPending()
	if InCombatLockdown() then
		self:Refresh()
	else
		self:Layout()
	end
end

local function AuraDiffers(prev, now)
	if (prev == nil) ~= (now == nil) then return true end
	return now ~= nil and (now.applications ~= prev.applications
		or now.expirationTime ~= prev.expirationTime or now.duration ~= prev.duration)
end

-- 事件带的变化信息（added / removed / updated）字段不稳 ⇒ 不信它：把关注集合逐个现查，只有
-- 「在 / 不在」「层数」「起止时刻」跟上次查到的不同才重画（增益不决定谁占哪一格 ⇒ 只重画，绝不走 Update）
-- ★ 换代只在这里：本代的光环值只查这一遍，其余重画全部复用
function Bar:RefreshAura()
	self.gen = self.gen + 1
	local changed = false
	for i = 1, #self.worn do
		local e = self.worn[i]
		local prev = self.auraVal[e.spellID]	-- 上一代的值：先取再查，查到就写回缓存
		if AuraDiffers(prev, Aura(e)) then changed = true end
	end
	return changed
end

-- ★★ 事件只置脏、一帧只落地一次：同一帧里常连着好几个（一次施法上两层、刷新时还叠着减益），
--    逐个现查 + 逐个重画整条 ⇒ 开销按事件数线性涨（查一次就是一张光环表 = 一份垃圾）
local function OnFlush()
	Bar.flushQueued = false
	if Bar:ApplyPending() then Bar:Repaint() end
end

local function Queue(self, aura, icd)
	if aura then self.auraDirty = true end
	if icd then self.icdDirty = true end
	if self.flushQueued then return end
	self.flushQueued = true
	C_Timer.After(0, OnFlush)
end

-- 待办同步落地（不画），返回"画面上有没有变化"；Repaint 在这基础上再整条画一遍
function Bar:ApplyPending()
	local auraDirty, icdDirty = self.auraDirty, self.icdDirty
	if not (auraDirty or icdDirty) then return false end
	self.auraDirty, self.icdDirty = false, false
	local changed = auraDirty and self:RefreshAura()
	if icdDirty then
		self:ReadItemIcd()
		changed = true
	end
	return changed
end

function Bar:AuraChanged() Queue(self, true, false) end

function Bar:ItemCooldownChanged() Queue(self, false, true) end

function Bar:ShowTip(btn)
	local e = btn.entry
	GameTooltip:SetOwner(btn, "ANCHOR_TOP")
	GameTooltip:AddLine(ns.ItemLabel(e), 1, 0.82, 0)
	GameTooltip:AddLine(ns.SpellLabel(e), 1, 1, 1)
	GameTooltip:AddLine(string.format(ns.L.TipInfo, e.duration, e.cooldown), 0.9, 0.9, 0.9)
	local mode = e.procOnly and ns.L.TipProcOnly or (e.clickable and ns.L.TipClickable)
	if mode then GameTooltip:AddLine(mode, 0.8, 0.8, 0.8) end
	GameTooltip:Show()
end

function Bar:CreateGrip()
	local g = CreateFrame("Button", nil, self.frame)
	AddSquareLayers(g)
	g.bg:SetAlpha(GRIP_BG_ALPHA)
	g:SetHitRectInsets(-GRIP_HIT_PAD, 0, 0, 0)
	g:RegisterForDrag("LeftButton")
	g:SetScript("OnDragStart", function()
		if ns.db.locked or InCombatLockdown() then return end
		self.frame:StartMoving()
		self.dragging = true
	end)
	g:SetScript("OnDragStop", function()
		if not self.dragging then return end
		self.dragging = false
		self.frame:StopMovingOrSizing()
		local x, y = self.frame:GetCenter()
		local cx, cy = UIParent:GetCenter()
		ns.db.point = { point = "CENTER", relPoint = "CENTER", x = x - cx, y = y - cy }
		-- ★ StartMoving 会顺手标 userPlaced（客户端自己也存一份位置），会和 db.point 打架 ⇒ 撤掉
		self.frame:SetUserPlaced(false)
		self:ApplyPosition()
	end)
	g:SetScript("OnEnter", function(f)
		g.bg:SetAlpha(0.8)
		GameTooltip:SetOwner(f, "ANCHOR_TOP")
		GameTooltip:AddLine(ns.L.GripTip, 1, 0.82, 0)
		GameTooltip:Show()
	end)
	g:SetScript("OnLeave", function()
		g.bg:SetAlpha(GRIP_BG_ALPHA)
		GameTooltip:Hide()
	end)
	self.grip = g
end

function Bar:UpdateGrip()
	self.grip:SetShown(not ns.db.locked and self.live > 0)
end

function Bar:ApplyPosition()
	local f = self.frame
	f:ClearAllPoints()
	local p = ns.db.point
	if p and p.point then
		f:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
	end
end

function Bar:ResetPosition()
	if InCombatLockdown() then return end
	ns.db.point = nil
	self:ApplyPosition()
end

function Bar:Create()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)

	self.frame = frame
	self.slots = {}
	self.resident = 0
	self.live = 0
	self.dragging = false
	self.procOrder = {}
	self.auraUp = {}
	self.auraAt = {}
	self.icd = {}
	self.gen = 0
	self.auraGen = {}
	self.auraVal = {}
	self.worn = {}
	self.auraDirty, self.icdDirty, self.flushQueued = false, false, false
	for i = 1, SLOT_MAX do
		self:CreateSlot(i)
	end
	self:CreateGrip()
	self:ApplyPosition()
end
