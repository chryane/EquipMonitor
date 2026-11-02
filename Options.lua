--[[ Options.lua - 设置面板（注册进系统设置 Settings API）
	 ① 显示设置：七行「标签 + 控件」，［重置位置］挂在「锁定位置」那行；② 监控列表：左列表 + 右表单
	   （没有［确定］—— 输入框回车、勾选框点击即写回）。
]]

local ADDON_NAME, ns = ...

local Options = {}
ns.Options = Options

local L = ns.L

local ROW_H = 26
local PAD = 10
local LIST_W = 210
local BOX_GAP = 2
local LIST_ROW_H = 28
local LIST_VISIBLE = 14   -- 左框最高按这么多行算（再多就框内滚，面板不再跟着条目数长）
local LIST_SLOTS = LIST_VISIBLE + 2   -- 行槽上限 = 视口能露出的行数（框统一加高 40，比这多两行）
local MON_EXTRA_H = 40
local SCROLLBAR_W = 8
local SEC_ROW_H = 24
local SEC_IN_GAP = 18
local DISP_ROWS = 7
local DISP_ROW_H = 30
local CHECK_SIZE = 30
local RESET_BTN_W = 90
local SLIDER_W = 200
local SLIDER_H = 19
local SLIDER_BOX_H = 25
local STEP_DX = 4
local STEP_L_W, STEP_L_H = 11, 19
local STEP_R_W, STEP_R_H = 9, 18
local STEP_GAP = 10
local SLIDER_BOX_W = STEP_DX + STEP_L_W + SLIDER_W + STEP_DX + STEP_R_W

local SEL_BTN_W, SEL_BTN_H = 26, 25
local SEL_GAP = 5
local SEL_BOX_H = 25
-- ★ 箭头底图在 26×25 框体里留了多少白，离线量不到 ⇒ 先按 0 摆；实机若偏了只改这一个数
local SEL_ART_INSET = 0
local BTN_GAP = 8
local MOVE_BTN_W = 66

local IO_TEXT_H = 88   -- 导出 / 导入两个文本域共用这个高度
local IO_SEL_W = 200   -- 导入规则选择控件定宽（◀ 值 ▶ 合计）
local START_BTN_W = 66

local SLOT_SIZE = 64
local SLOT_INSET = 7
local ICON_COL = SLOT_SIZE + 8
local CTRL_GAP = 50
local DISP_CTRL_DX = 30   -- 显示设置的控件列再右移（用户 2026-10-19：统一后移 30）
local EDIT_H = 25
local EDIT_RIGHT = 10
-- ★ 控件列对的是**可见左缘**：输入框补 -5（Left 贴图锚在 x=-5）、勾选框补 CheckInset（美术居中留白）、滑条不补
local EDIT_DX = -5
local function CheckInset(size) return math.floor(size / 10 + 0.5) end
local OTHER_LABEL_DX = 10

local TOP_DY = 4
local TITLE_H = 22
local TITLE_TO_BOX = 12
local SEC_GAP = 20
local BOTTOM = 16

local TAB_H = 37
local TAB_TEXT_PAD = 40
local TAB_GAP = 4
local TAB_SHIFT = -10

local SLOT_TEX = "Interface\\Buttons\\UI-Quickslot"
local SLOT_TEX_INSET = 0.19

local ROW_HL = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"
local ROW_HL_R, ROW_HL_G, ROW_HL_B = 0.22, 0.35, 0.65
local ROW_HL_HOVER_ALPHA = 0.5

local FONT_TITLE = "GameFontNormalLarge"
local FONT_SECTION = "GameFontNormal"
local FONT_FORM_LABEL = "GameFontNormal"
local FONT_DISABLED = "GameFontDisable"
local FONT_LABEL = "GameFontHighlight"
local FONT_LABEL_SEL = "GameFontNormal"
local FONT_TAB = "GameFontNormalSmall"
local FONT_TAB_SEL = "GameFontHighlightSmall"

local ICON_VALUES = { ns.ICON_ITEM, ns.ICON_SPELL }
local function IconSrcText(v)
	return v == ns.ICON_SPELL and L.IconSpell or L.IconItem
end

-- 导入规则三档 → 值框文字（键就是 ns:Import 的 rule）
local RULE_TEXT = { skip = L.RuleSkip, overwrite = L.RuleOverwrite, new = L.RuleNew }

local function CreateHeader(parent, text)
	local f = parent:CreateFontString(nil, "OVERLAY", FONT_TITLE)
	f:SetText(text)
	return f
end

local function CreateLabel(parent, text, font)
	local f = parent:CreateFontString(nil, "OVERLAY", font or FONT_LABEL)
	f:SetJustifyH("LEFT")
	f:SetWordWrap(false)
	f:SetText(text or "")
	return f
end

local function CreateRowLabel(row, text, font, dx)
	local f = CreateLabel(row, text, font)
	f:SetPoint("LEFT", row, "LEFT", dx or 0, 0)
	return f
end

local function CreateBox(parent)
	local box = CreateFrame("Frame", nil, parent, "TooltipBackdropTemplate")
	box:SetBackdropColor(0, 0, 0, 0)
	box:SetBackdropBorderColor(0.62, 0.62, 0.62, 1)
	box.NineSlice:SetFrameLevel(box:GetFrameLevel())
	return box
end

local TAB_TEX = {
	{ "Options_Tab_Left", "Options_Tab_Middle", "Options_Tab_Right" },
	{ "Options_Tab_Active_Left", "Options_Tab_Active_Middle", "Options_Tab_Active_Right" },
}

local function CreateTab(parent)
	local tab = CreateFrame("Button", nil, parent)
	tab:SetSize(100, TAB_H)
	tab.left = tab:CreateTexture(nil, "BACKGROUND")
	tab.left:SetPoint("BOTTOMLEFT")
	tab.right = tab:CreateTexture(nil, "BACKGROUND")
	tab.right:SetPoint("BOTTOMRIGHT")
	tab.middle = tab:CreateTexture(nil, "BACKGROUND")
	tab.middle:SetPoint("TOPLEFT", tab.left, "TOPRIGHT")
	tab.middle:SetPoint("TOPRIGHT", tab.right, "TOPLEFT")
	tab.text = tab:CreateFontString(nil, "OVERLAY", FONT_TAB)
	return tab
end

local function SetTabSelected(tab, selected)
	local tex = TAB_TEX[selected and 2 or 1]
	tab.left:SetAtlas(tex[1], true)
	tab.middle:SetAtlas(tex[2], true)
	tab.right:SetAtlas(tex[3], true)
	if selected then
		tab.text:SetPoint("BOTTOM", 0, 6)
		tab.text:SetFontObject(FONT_TAB_SEL)
	else
		tab.text:SetPoint("BOTTOM", 0, 4)
		tab.text:SetFontObject(FONT_TAB)
	end
end

local function CreateRow(parent, height)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(height or ROW_H)
	return row
end

local function CreateEdit(parent, onPreview, numeric)
	local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	edit:SetHeight(EDIT_H)
	-- 边框三片贴图在模板里写死 20 高、不跟着框体走 ⇒ 要跟下拉框等高就得自己把它们拉高
	edit.Left:SetHeight(EDIT_H)
	edit.Right:SetHeight(EDIT_H)
	edit.Middle:SetHeight(EDIT_H)
	edit:SetAutoFocus(false)
	if numeric ~= false then edit:SetNumeric(true) end
	edit:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
	edit:SetScript("OnEnterPressed", function(f)
		f:ClearFocus()
		if onPreview then onPreview() end
		Options:CommitOnEnter()
	end)
	if onPreview then
		edit:SetScript("OnEditFocusLost", onPreview)
	end
	return edit
end

-- ★ 多行文本域：没有现成模板（InputBoxTemplate 是单行的），自己套一层框 + 无模板 EditBox
local function CreateTextArea(parent, height)
	local box = CreateBox(parent)
	box:SetHeight(height)
	local edit = CreateFrame("EditBox", nil, box)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(0)
	edit:SetFontObject("ChatFontNormal")
	edit:SetTextInsets(6, 6, 6, 6)
	edit:SetPoint("TOPLEFT", box, "TOPLEFT", 7, -7)
	edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -7, 7)
	edit:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
	box.edit = edit
	return box
end

local function BoxTip(box, newText, savedText)
	box.tipNew, box.tipSaved = newText, savedText
	box:SetScript("OnEnter", function(f)
		local text = Options.editing and f.tipSaved or f.tipNew
		if not text then return end
		GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
		GameTooltip:AddLine(text, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	box:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function HoverTip(frame, text)
	frame:SetScript("OnEnter", function(f)
		GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
		GameTooltip:AddLine(text, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ★ 模板的五张美术是 atlas 原生尺寸、没有锚点（默认居中）⇒ 照原尺寸用，SetSize 缩放反会错位；
-- ★ CheckButton:SetChecked 不触发 OnClick ⇒ 面板回填勾选状态不会被当成"用户改动"提交
local function CreateCheck(parent)
	local cb = CreateFrame("CheckButton", nil, parent, "MinimalCheckboxTemplate")
	cb:SetSize(CHECK_SIZE, CHECK_SIZE - 1)   -- 模板原尺寸 30×29
	return cb
end

local function CreateButton(parent, label, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(label)
	return b
end

-- ★ 自己拼而不继承暴雪的模板：那个外层固定 40 高、条也被撑到 40，塞不进这里 30 的行高；
-- ★ SetValue 会触发 OnValueChanged ⇒ 回填靠 Options.filling 区分；读数必须锚**这一个控件自己**
local function CreateSlider(row, minV, maxV, onChanged)
	local box = CreateFrame("Frame", nil, row)
	box:SetSize(SLIDER_BOX_W, SLIDER_BOX_H)

	local s = CreateFrame("Slider", nil, box, "MinimalSliderTemplate")
	s:SetSize(SLIDER_W, SLIDER_H)
	s:SetPoint("LEFT", box, "LEFT", STEP_DX + STEP_L_W, 0)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(1)
	s:SetObeyStepOnDrag(true)
	box.slider = s

	local function MakeStepButton(atlas, w, h, dir)
		local b = CreateFrame("Button", nil, box)
		b:SetSize(w, h)
		b.tex = b:CreateTexture(nil, "BACKGROUND")
		b.tex:SetAtlas(atlas, true)
		b.tex:SetPoint("CENTER")
		if dir < 0 then
			b:SetPoint("RIGHT", s, "LEFT", -STEP_DX, 0)
		else
			b:SetPoint("LEFT", s, "RIGHT", STEP_DX, 0)
		end
		b:SetScript("OnClick", function()
			s:SetValue(s:GetValue() + dir)
		end)
		return b
	end
	box.back = MakeStepButton("Minimal_SliderBar_Button_Left", STEP_L_W, STEP_L_H, -1)
	box.forward = MakeStepButton("Minimal_SliderBar_Button_Right", STEP_R_W, STEP_R_H, 1)

	-- ★ 读数先建、脚本后挂：SetMinMaxValues / SetValue 都会触发 OnValueChanged，而处理函数里要写它
	box.reading = box:CreateFontString(nil, "OVERLAY", FONT_LABEL)
	box.reading:SetPoint("LEFT", box.forward, "RIGHT", STEP_GAP, 0)
	s:SetScript("OnValueChanged", function(_, v)
		box.reading:SetText(string.format("%d", v))
		if not Options.filling then onChanged(v) end
	end)
	return box
end

local function CreateStepButton(parent, iconAtlas)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(SEL_BTN_W, SEL_BTN_H)
	b.art = b:CreateTexture(nil, "BACKGROUND")
	b.art:SetAtlas("common-dropdown-c-button", true)
	b.art:SetPoint("CENTER")
	b.icon = b:CreateTexture(nil, "OVERLAY")
	b.icon:SetAtlas(iconAtlas, true)
	b.icon:SetPoint("CENTER")

	local function State(atlas, dx, dy)
		b.art:SetAtlas(atlas, true)
		b.icon:ClearAllPoints()
		b.icon:SetPoint("CENTER", dx, dy)
	end
	b:SetScript("OnEnter", function() State("common-dropdown-c-button-hover-2", 0, 0) end)
	b:SetScript("OnLeave", function() State("common-dropdown-c-button", 0, 0) end)
	b:SetScript("OnMouseDown", function() State("common-dropdown-c-button-pressedhover-2", 2, -1) end)
	b:SetScript("OnMouseUp", function() State("common-dropdown-c-button-hover-2", 0, 0) end)
	return b
end

local function OpenValueMenu(owner, values, textOf, get, apply)
	-- MenuUtil 在 Blizzard_Menu（LoadOnDemand），面板打开时未必已加载
	if not MenuUtil then C_AddOns.LoadAddOn("Blizzard_Menu") end
	local root = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
	Menu.PopulateDescription(function(_, desc)
		for i = 1, #values do
			local v = values[i]
			desc:CreateHighlightRadio(textOf(v), function() return get() == v end, function() apply(v) end)
		end
	end, owner, root)
	root:SetMinimumWidth(owner:GetWidth())
	Menu.GetManager():OpenMenu(owner, root, AnchorUtil.CreateAnchor("TOPLEFT", owner, "BOTTOMLEFT", 0, 0))
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

local function CreateSelect(parent, values, textOf, tip, get, commit)
	local dec = CreateStepButton(parent, "common-dropdown-icon-back")
	local inc = CreateStepButton(parent, "common-dropdown-icon-next")
	local box = CreateFrame("Button", nil, parent)
	box:SetHeight(SEL_BOX_H)
	box.bg = box:CreateTexture(nil, "BACKGROUND")
	box.bg:SetAtlas("common-dropdown-c-button", true)
	box.bg:SetPoint("TOPLEFT", box, "TOPLEFT", -7, 7)
	box.bg:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 7, -7)
	box.text = box:CreateFontString(nil, "OVERLAY", FONT_LABEL)
	box.text:SetPoint("CENTER")

	-- ★ 定位一律由 Layout 摆：进 cleared 表的控件都得在那里重锚，否则被 ClearAllPoints 清掉
	local function Apply(v)
		commit(v)
		box.text:SetText(textOf(v))
	end

	local function Step(delta)
		local cur, idx = get(), 1
		for i = 1, #values do
			if values[i] == cur then idx = i break end
		end
		idx = idx + delta
		if idx < 1 then idx = #values elseif idx > #values then idx = 1 end
		Apply(values[idx])
	end
	dec:SetScript("OnClick", function() Step(-1) end)
	inc:SetScript("OnClick", function() Step(1) end)
	box:SetScript("OnClick", function() OpenValueMenu(box, values, textOf, get, Apply) end)
	-- hover 换底 + 提示写在同一个处理器里（SetScript 会互相覆盖）
	box:SetScript("OnEnter", function(f)
		box.bg:SetAtlas("common-dropdown-c-button-hover-2", true)
		GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
		GameTooltip:AddLine(tip, 1, 1, 1, true)
		GameTooltip:AddLine(L.PickOpen, 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	box:SetScript("OnLeave", function()
		box.bg:SetAtlas("common-dropdown-c-button", true)
		GameTooltip:Hide()
	end)
	return dec, box, inc
end

local function CreateSlotBox(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(SLOT_SIZE, SLOT_SIZE)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetTexture(SLOT_TEX)
	f.bg:SetTexCoord(SLOT_TEX_INSET, 1 - SLOT_TEX_INSET, SLOT_TEX_INSET, 1 - SLOT_TEX_INSET)
	f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", SLOT_INSET, -SLOT_INSET)
	f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -SLOT_INSET, SLOT_INSET)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", SLOT_INSET, -SLOT_INSET)
	f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -SLOT_INSET, SLOT_INSET)
	f.icon:Hide()
	return f
end

-- ★ 本客户端的 SCROLL_FRAME_SCROLL_BAR_TEMPLATE 指向未定义模板，须自建 MinimalScrollBar
local function CreateScrollArea(panel, hideIfUnscrollable)
	local s = CreateFrame("ScrollFrame", nil, panel)
	local b = CreateFrame("EventFrame", nil, s, "MinimalScrollBar")
	b:SetPoint("TOPLEFT", s, "TOPRIGHT", 0, -4)
	b:SetPoint("BOTTOMLEFT", s, "BOTTOMRIGHT", -1, 7)
	b:SetHideIfUnscrollable(hideIfUnscrollable)
	ScrollUtil.InitScrollFrameWithScrollBar(s, b)
	return s
end

-- ★ 行槽只有 LIST_SLOTS 个：滚动时把同一批行重绑到别的条目上。客户端不销毁控件 ⇒
--   按条目数建行的话，导入一堆重复条目后就算全删了内存也回不去
function Options:GetRow(slot)
	local rows = self.rows
	if rows[slot] then return rows[slot] end

	local row = {}
	row.frame = CreateFrame("Button", nil, self.listContent)
	row.frame:SetHeight(LIST_ROW_H)
	row.frame:SetHighlightTexture(ROW_HL, "ADD")
	row.frame:GetHighlightTexture():SetVertexColor(ROW_HL_R, ROW_HL_G, ROW_HL_B)
	row.frame:GetHighlightTexture():SetAlpha(ROW_HL_HOVER_ALPHA)
	row.sel = row.frame:CreateTexture(nil, "BACKGROUND")
	row.sel:SetTexture(ROW_HL)
	row.sel:SetVertexColor(ROW_HL_R, ROW_HL_G, ROW_HL_B)
	row.sel:SetBlendMode("ADD")
	row.sel:SetAllPoints(row.frame)
	row.sel:Hide()
	row.icon = row.frame:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(22, 22)
	row.icon:SetPoint("LEFT", row.frame, "LEFT", 4, 0)
	row.label = CreateLabel(row.frame)
	row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
	row.frame:SetScript("OnClick", function() Options:ShowDetail(row.index) end)

	rows[slot] = row
	return row
end

-- 只重排凑到视口里的那几行：第 slot 个槽显示 offset + slot 那条，位置按条目下标算
function Options:ReloadList()
	local entries = ns.db.entries
	local total = #entries
	local maxOff = math.max(total - LIST_SLOTS, 0)
	local off = math.floor(self.listScroll:GetVerticalScroll() / LIST_ROW_H + 0.01)
	if off > maxOff then
		off = maxOff
		self.listScroll:SetVerticalScroll(off * LIST_ROW_H)   -- 条目变少 ⇒ 把滚动位置拉回还能停的那一行
	end

	local n = math.min(total - off, LIST_SLOTS)
	for slot = 1, n do
		local row, e = self:GetRow(slot), entries[off + slot]
		row.index = off + slot
		row.frame:ClearAllPoints()
		row.frame:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", 0, -(row.index - 1) * LIST_ROW_H)
		row.frame:SetPoint("TOPRIGHT", self.listContent, "TOPRIGHT", 0, -(row.index - 1) * LIST_ROW_H)
		local selected = self.mode == "detail" and self.editing == row.index
		row.icon:SetTexture(ns.ItemIcon(e.itemID))
		row.label:SetText(ns.ItemLabel(e))
		row.label:SetFontObject(selected and FONT_LABEL_SEL or FONT_LABEL)
		row.sel:SetShown(selected)
		row.frame:Show()
	end
	for slot = n + 1, #self.rows do
		self.rows[slot].frame:Hide()
	end
end

function Options:FitForm(e)
	self.itemEdit:SetText(e and tostring(e.itemID) or "")
	self.spellEdit:SetText(e and tostring(e.spellID) or "")
	self.durEdit:SetText(e and tostring(e.duration) or "")
	self.cdEdit:SetText(e and tostring(e.cooldown) or "")
	self.itemName:SetText(e and e.itemName or "")
	self.spellName:SetText(e and e.spellName or "")
	self.autoItemName, self.autoSpellName = nil, nil
	self.clickCheck:SetChecked(e and e.clickable or nil)
	self.enabledCheck:SetChecked(not e or e.enabled ~= false)
	self.procCheck:SetChecked(e and e.procOnly or nil)
	-- ★ 老存档没有 iconSource 字段 ⇒ 缺省当「物品图标」（新建态的初始值也在这里）
	self.iconSource = (e and e.iconSource) or ns.ICON_ITEM
	self:UpdateItemPreview()
	self:UpdateSpellPreview()
	self:UpdateClickState()
	self:Sync()
end

function Options:ShowNew()
	self.mode = "new"
	self.editing = nil
	self:FitForm(nil)
end

function Options:ShowDetail(index)
	self.mode = "detail"
	self.editing = index and ns.db.entries[index] and index or nil
	-- 没有条目 ⇒ 空白页（Sync 里整块表单都不画）
	self:FitForm(self.editing and ns.db.entries[self.editing])
end

function Options:ShowTransfer()
	self.mode = "io"
	self.editing = nil
	self:Sync()
end

function Options:UpdateImportState()
	self.ioImpBtn:SetEnabled((self.ioPasteEdit:GetText():gsub("%s+", "")) ~= "")
end

function Options:ClearResult()
	if self.ioResult:GetText() ~= "" then self.ioResult:SetText("") end
end

function Options:DoExport()
	if #ns.db.entries == 0 then return end
	self.ioExpEdit:SetText(ns.Encode(ns.db.entries))
	self.ioExpEdit:SetFocus()
	self.ioExpEdit:HighlightText()
end

function Options:DoImport()
	local list = ns.Decode(self.ioPasteEdit:GetText())
	if not list then
		self.ioResult:SetText(L.ResBad)
		return
	end
	local added, skipped, replaced = ns:Import(list, self.ioRule)
	self.ioResult:SetText(string.format(L.ResImport, added, skipped, replaced))
end

-- ★ MinimalCheckboxArtTemplate 没有 DisabledTexture，SetChecked(false) 只拦点击 ⇒ "灰"要自己来
function Options:UpdateClickState()
	local click = self.clickCheck:GetChecked() and true or false
	local proc = self.procCheck:GetChecked() and true or false
	self.clickCheck:SetEnabled(not proc)
	self.clickCheck:SetAlpha(proc and 0.4 or 1)
	self.clickLabel:SetFontObject(proc and FONT_DISABLED or FONT_FORM_LABEL)
	self.procCheck:SetEnabled(not click)
	self.procCheck:SetAlpha(click and 0.4 or 1)
	self.procLabel:SetFontObject(click and FONT_DISABLED or FONT_LABEL)
end

local function AutoFill(box, auto, text)
	local cur = box:GetText()
	if cur == "" or cur == auto then box:SetText(text) end
	return text
end

function Options:UpdateItemPreview()
	local itemID = tonumber(self.itemEdit:GetText())
	if not itemID or itemID <= 0 then
		self.itemSlot.icon:Hide()
		self.autoItemName = nil
		self.itemName:SetText("")
		return
	end
	self.itemSlot.icon:SetTexture(ns.ItemIcon(itemID))
	self.itemSlot.icon:Show()
	self.autoItemName = AutoFill(self.itemName, self.autoItemName, ns.ItemName(itemID))
end

function Options:UpdateSpellPreview()
	local spellID = tonumber(self.spellEdit:GetText())
	if not spellID or spellID <= 0 then
		self.spellSlot.icon:Hide()
		self.autoSpellName = nil
		self.spellName:SetText("")
		return
	end
	self.spellSlot.icon:SetTexture(ns.SpellIcon(spellID))
	self.spellSlot.icon:Show()
	self.autoSpellName = AutoFill(self.spellName, self.autoSpellName, ns.SpellName(spellID))
end

-- ★ 只存"与现取名不同"的输入，否则物品没缓存时会把占位文案冻结进存档
local function NameOverride(text, derived)
	if text == "" or text == derived then return nil end
	return text
end

function Options:ReadForm()
	local itemID = tonumber(self.itemEdit:GetText())
	local spellID = tonumber(self.spellEdit:GetText())
	if not itemID or itemID <= 0 or not spellID or spellID <= 0 then
		print(L.BadIDs)
		return nil
	end
	return {
		enabled = self.enabledCheck:GetChecked() and true or false,
		itemID = itemID,
		spellID = spellID,
		itemName = NameOverride(self.itemName:GetText(), ns.ItemName(itemID)),
		spellName = NameOverride(self.spellName:GetText(), ns.SpellName(spellID)),
		duration = tonumber(self.durEdit:GetText()) or 0,
		cooldown = tonumber(self.cdEdit:GetText()) or 0,
		clickable = self.clickCheck:GetChecked() and true or false,
		procOnly = self.procCheck:GetChecked() and true or false,
		iconSource = self.iconSource,
	}
end

function Options:Add()
	local entry = self:ReadForm()
	if not entry then return end
	ns:Add(entry)
	self:ShowNew()
end

-- ★ editing 为 nil（新建页 / 详情空白态）什么都不做，免得半填的表单被回车误存一条
function Options:CommitOnEnter()
	if not self.editing then return end
	self:Commit()
end

function Options:Commit()
	local entry = self:ReadForm()
	if not entry then return end
	local index = self.editing
	ns:Save(index, entry)
	self:ShowDetail(index)
end

function Options:Delete()
	if not self.editing then return end
	ns:Remove(self.editing)
	self:ShowDetail(nil)
end

function Options:MoveEntry(delta)
	local i = self.editing
	if not i then return end
	local j = i + delta
	if not ns.db.entries[j] then return end
	ns:Move(i, delta)
	self:ShowDetail(j)
end

function Options:Build()
	local panel = CreateFrame("Frame")
	panel.name = ADDON_NAME
	-- 必须显式 Hide：设置界面挂载面板时才不会漏掉 OnShow
	panel:Hide()
	self.panel = panel

	panel:SetScript("OnShow", function()
		panel:ClearAllPoints()
		panel:SetAllPoints(panel:GetParent())
		self:BuildContent()
		self:Reload()
		-- 每次打开都补问一次没名字的物品（导入来的 ID 可能还没到）
		ns.RequestItemData(ns.db.entries)
	end)
end

function Options:BuildContent()
	if self.content then return end
	local panel = self.panel

	local scroll = CreateScrollArea(panel)
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -56)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 4)
	self.scroll = scroll

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(520, 640)
	scroll:SetScrollChild(content)
	self.content = content
	scroll:SetScript("OnSizeChanged", function(_, w)
		if w > 0 then content:SetWidth(w) end
	end)

	self.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
	self.title:SetJustifyH("LEFT")
	self.title:SetText(ADDON_NAME)
	self.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
	self.titleLine = panel:CreateTexture(nil, "ARTWORK")
	self.titleLine:SetAtlas("Options_HorizontalDivider", true)
	self.titleLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -46)
	self.titleLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -46)

	self.rows = {}
	self:BuildDisplay(content)
	self:BuildMonitor(content)
	-- 打开面板默认停在「详情」（没选中条目就是空白页）
	self:ShowDetail()
end

function Options:BuildDisplay(parent)
	self.displayHeader = CreateHeader(parent, L.SecBar)
	self.displayBox = CreateBox(parent)

	self.barEnabledRow = CreateRow(parent, DISP_ROW_H)
	self.barEnabledLabel = CreateRowLabel(self.barEnabledRow, L.BarEnabled, FONT_LABEL)
	self.barEnabledCheck = CreateCheck(self.barEnabledRow)
	self.barEnabledCheck:SetScript("OnClick", function(f)
		ns.db.enabled = f:GetChecked() and true or false
		ns.Bar:Update()
	end)

	self.lockRow = CreateRow(parent, DISP_ROW_H)
	self.lockLabel = CreateRowLabel(self.lockRow, L.Lock, FONT_LABEL)
	self.lockCheck = CreateCheck(self.lockRow)
	self.lockCheck:SetScript("OnClick", function(f)
		ns.db.locked = f:GetChecked() and true or false
		if not InCombatLockdown() then ns.Bar:UpdateGrip() end
	end)
	self.resetBtn = CreateButton(parent, L.ResetPos, RESET_BTN_W)
	self.resetBtn:SetScript("OnClick", function()
		ns.Bar:ResetPosition()
		print(L.ResetDone)
	end)

	self.iconGapRow = CreateRow(parent, DISP_ROW_H)
	self.iconGapLabel = CreateRowLabel(self.iconGapRow, L.IconGap, FONT_LABEL)
	self.iconGapSlider = CreateSlider(self.iconGapRow, 0, 4, function(v)
		ns.db.gap = v
		ns.Bar:Reflow()
	end)

	self.iconSizeRow = CreateRow(parent, DISP_ROW_H)
	self.iconSizeLabel = CreateRowLabel(self.iconSizeRow, L.IconSize, FONT_LABEL)
	self.iconSizeSlider = CreateSlider(self.iconSizeRow, 32, 64, function(v)
		ns.db.slotSize = v
		ns.Bar:Reflow()
	end)

	self.textSizeRow = CreateRow(parent, DISP_ROW_H)
	self.textSizeLabel = CreateRowLabel(self.textSizeRow, L.TextSize, FONT_LABEL)
	self.textSizeSlider = CreateSlider(self.textSizeRow, 10, 28, function(v)
		ns.db.fontSize = v
		ns.Bar:Reflow()
	end)

	self.tipRow = CreateRow(parent, DISP_ROW_H)
	self.tipLabel = CreateRowLabel(self.tipRow, L.ShowTip, FONT_LABEL)
	self.tipCheck = CreateCheck(self.tipRow)
	self.tipCheck:SetScript("OnClick", function(f)
		ns.db.tooltip = f:GetChecked() and true or false
	end)

	self.swapRow = CreateRow(parent, DISP_ROW_H)
	self.swapLabel = CreateRowLabel(self.swapRow, L.SwapTrinkets, FONT_LABEL)
	self.swapCheck = CreateCheck(self.swapRow)
	self.swapCheck:SetScript("OnClick", function(f)
		ns.db.swapTrinkets = f:GetChecked() and true or false
		ns.Bar:Update()
	end)
	HoverTip(self.swapCheck, L.SwapTip)
end

function Options:BuildMonitor(parent)
	self.monHeader = CreateHeader(parent, L.SecMonitor)

	self.listBox = CreateBox(parent)
	self.emptyHint = CreateLabel(self.listBox, L.ListEmpty)
	self.emptyHint:SetPoint("TOPLEFT", self.listBox, "TOPLEFT", PAD + 4, -PAD)

	self.listScroll = CreateScrollArea(self.listBox, true)
	self.listScroll:SetPoint("TOPLEFT", self.listBox, "TOPLEFT", PAD, -PAD)
	self.listScroll:SetPoint("BOTTOMRIGHT", self.listBox, "BOTTOMRIGHT", -(PAD + SCROLLBAR_W), PAD)
	self.listContent = CreateFrame("Frame", nil, self.listScroll)
	self.listScroll:SetScrollChild(self.listContent)
	self.listContent:SetWidth(LIST_W - PAD * 2 - SCROLLBAR_W)
	-- ★ ScrollUtil 已经占掉 OnVerticalScroll，行槽复用只能挂在它后面
	self.listScroll:HookScript("OnVerticalScroll", function() Options:ReloadList() end)

	self.formBox = CreateBox(parent)

	self.formArea = CreateFrame("Frame", nil, self.formBox)

	self.tabNew = CreateTab(parent)
	self.tabDetail = CreateTab(parent)
	self.tabImport = CreateTab(parent)
	self.tabNew.text:SetText(L.TabNew)
	self.tabDetail.text:SetText(L.TabDetail)
	self.tabImport.text:SetText(L.TabIO)
	self.tabNew:SetScript("OnClick", function() Options:ShowNew() end)
	-- 已停在"详情"再点"详情"什么都不做（否则会把正在编辑的表单清空）
	self.tabDetail:SetScript("OnClick", function()
		if Options.mode == "detail" then return end
		Options:ShowDetail(nil)
	end)
	-- 同理：已在数据导入页就不再进来，否则会把导出串和导入结果冲掉
	self.tabImport:SetScript("OnClick", function()
		if Options.mode == "io" then return end
		Options:ShowTransfer()
	end)
	local tabLevel = self.formBox:GetFrameLevel() + 2
	self.tabNew:SetFrameLevel(tabLevel)
	self.tabDetail:SetFrameLevel(tabLevel)
	self.tabImport:SetFrameLevel(tabLevel)

	self.itemSecRow = CreateRow(self.formArea, SEC_ROW_H)
	self.itemSec = CreateRowLabel(self.itemSecRow, L.SecItem, FONT_SECTION)
	self.spellSecRow = CreateRow(self.formArea, SEC_ROW_H)
	self.spellSec = CreateRowLabel(self.spellSecRow, L.SecSpell, FONT_SECTION)
	self.otherSecRow = CreateRow(self.formArea, SEC_ROW_H)
	self.otherSec = CreateRowLabel(self.otherSecRow, L.SecOther, FONT_SECTION)

	self.itemIDRow = CreateRow(self.formArea)
	self.itemIDLabel = CreateRowLabel(self.itemIDRow, L.ItemID, FONT_FORM_LABEL)
	self.itemEdit = CreateEdit(self.itemIDRow, function() Options:UpdateItemPreview() end)

	self.itemNameRow = CreateRow(self.formArea)
	self.itemNameLabel = CreateRowLabel(self.itemNameRow, L.ItemName, FONT_FORM_LABEL)
	self.itemName = CreateEdit(self.itemNameRow, nil, false)

	self.clickRow = CreateRow(self.formArea)
	self.clickLabel = CreateRowLabel(self.clickRow, L.ClickCast, FONT_FORM_LABEL)
	self.clickCheck = CreateCheck(self.clickRow)
	self.clickCheck:SetScript("OnClick", function()
		-- 互斥：刚勾上就把「仅法术触发时显示」清掉（回填走 SetChecked，不会进来）
		if Options.clickCheck:GetChecked() then Options.procCheck:SetChecked(false) end
		Options:UpdateClickState()
		Options:CommitOnEnter()
	end)
	HoverTip(self.clickCheck, L.ClickTip)

	self.spellIDRow = CreateRow(self.formArea)
	self.spellIDLabel = CreateRowLabel(self.spellIDRow, L.SpellID, FONT_FORM_LABEL)
	self.spellEdit = CreateEdit(self.spellIDRow, function() Options:UpdateSpellPreview() end)

	self.spellNameRow = CreateRow(self.formArea)
	self.spellNameLabel = CreateRowLabel(self.spellNameRow, L.SpellName, FONT_FORM_LABEL)
	self.spellName = CreateEdit(self.spellNameRow, nil, false)

	self.durRow = CreateRow(self.formArea)
	self.durLabel = CreateRowLabel(self.durRow, L.Duration, FONT_FORM_LABEL)
	self.durEdit = CreateEdit(self.durRow)

	self.cdRow = CreateRow(self.formArea)
	self.cdLabel = CreateRowLabel(self.cdRow, L.Cooldown, FONT_FORM_LABEL)
	self.cdEdit = CreateEdit(self.cdRow)

	BoxTip(self.itemEdit, L.ItemIDTip, L.ItemIDSavedTip)
	BoxTip(self.spellEdit, L.SpellIDTip, L.SpellIDSavedTip)
	BoxTip(self.cdEdit, L.CooldownTip, L.CooldownSavedTip)
	BoxTip(self.itemName, nil, L.EnterSaveTip)
	BoxTip(self.spellName, nil, L.EnterSaveTip)
	BoxTip(self.durEdit, nil, L.EnterSaveTip)

	self.enabledRow = CreateRow(self.formArea)
	self.enabledLabel = CreateRowLabel(self.enabledRow, L.Enabled, FONT_LABEL, OTHER_LABEL_DX)
	self.enabledCheck = CreateCheck(self.enabledRow)
	self.enabledCheck:SetScript("OnClick", function() Options:CommitOnEnter() end)

	self.procRow = CreateRow(self.formArea)
	self.procLabel = CreateRowLabel(self.procRow, L.ProcOnly, FONT_LABEL, OTHER_LABEL_DX)
	self.procCheck = CreateCheck(self.procRow)
	self.procCheck:SetScript("OnClick", function()
		-- 互斥：刚勾上就把「点击施法」清掉（回填走 SetChecked，不会进来）
		if Options.procCheck:GetChecked() then Options.clickCheck:SetChecked(false) end
		Options:UpdateClickState()   -- 先联动（置灰 / 取消勾选），再落库
		Options:CommitOnEnter()
	end)

	self.iconSrcRow = CreateRow(self.formArea)
	self.iconSrcLabel = CreateRowLabel(self.iconSrcRow, L.IconSource, FONT_LABEL, OTHER_LABEL_DX)
	self.iconSrcDec, self.iconSrcBox, self.iconSrcInc = CreateSelect(self.iconSrcRow,
		ICON_VALUES, IconSrcText, L.IconSourceTip,
		function() return Options.iconSource end,
		function(v) Options.iconSource = v; Options:CommitOnEnter() end)

	self.itemSlot = CreateSlotBox(self.formArea)
	self.spellSlot = CreateSlotBox(self.formArea)

	self.addBtn = CreateButton(self.formArea, L.Add, 80)
	self.addBtn:SetScript("OnClick", function() Options:Add() end)
	self.delBtn = CreateButton(self.formArea, L.Delete, 66)
	self.delBtn:SetScript("OnClick", function() Options:Delete() end)

	self.upBtn = CreateButton(self.formArea, L.MoveUp, MOVE_BTN_W)
	self.upBtn:SetScript("OnClick", function() Options:MoveEntry(-1) end)
	self.downBtn = CreateButton(self.formArea, L.MoveDown, MOVE_BTN_W)
	self.downBtn:SetScript("OnClick", function() Options:MoveEntry(1) end)

	self:BuildTransfer()
end

-- 右框里"数据导入"这一页：导出（开始 + 可复制文本域）/ 导入（规则 + 粘贴框 + 开始 + 结果）
function Options:BuildTransfer()
	local area = CreateFrame("Frame", nil, self.formBox)
	area:SetShown(false)
	self.ioArea = area
	self.ioRule = "skip"

	self.ioExpHead = CreateRow(area, 24)
	self.ioExpLabel = CreateRowLabel(self.ioExpHead, L.SecExport, FONT_SECTION)
	self.ioExportBtn = CreateButton(self.ioExpHead, L.Start, START_BTN_W)
	self.ioExportBtn:SetScript("OnClick", function() Options:DoExport() end)
	self.ioExpBox = CreateTextArea(area, IO_TEXT_H)
	self.ioExpEdit = self.ioExpBox.edit
	-- 点进去就全选，Ctrl+C 直接拷整串
	self.ioExpEdit:SetScript("OnEditFocusGained", function(f) f:HighlightText() end)
	HoverTip(self.ioExpEdit, L.CopyTip)

	self.ioImpHead = CreateRow(area, 24)
	self.ioImpLabel = CreateRowLabel(self.ioImpHead, L.SecImport, FONT_SECTION)

	self.ioRuleRow = CreateRow(area)
	self.ioRuleLabel = CreateRowLabel(self.ioRuleRow, L.RuleLabel, FONT_LABEL, OTHER_LABEL_DX)
	self.ioRuleDec, self.ioRuleBox, self.ioRuleInc = CreateSelect(self.ioRuleRow,
		{ "skip", "overwrite", "new" }, function(v) return RULE_TEXT[v] end, L.RuleTip,
		function() return Options.ioRule end,
		function(v) Options.ioRule = v end)
	self.ioRuleBox.text:SetText(RULE_TEXT[self.ioRule])

	self.ioPasteBox = CreateTextArea(area, IO_TEXT_H)
	self.ioPasteEdit = self.ioPasteBox.edit
	HoverTip(self.ioPasteEdit, L.PasteTip)
	self.ioPasteEdit:SetScript("OnTextChanged", function()
		Options:UpdateImportState()
		Options:ClearResult()
	end)

	self.ioBtnRow = CreateRow(area)
	self.ioImpBtn = CreateButton(self.ioBtnRow, L.Start, START_BTN_W)
	self.ioImpBtn:SetScript("OnClick", function() Options:DoImport() end)

	self.ioResult = CreateLabel(area, "", FONT_LABEL)
	self.ioResult:SetJustifyH("LEFT")
end

local function CtrlX(labels)
	local w = 0
	for i = 1, #labels do
		local lw = labels[i]:GetStringWidth()
		if lw > w then w = lw end
	end
	return w + CTRL_GAP
end

function Options:Layout()
	-- ★ SetPoint 是"占位"语义，上一次的锚点不会自己消失，每次先清空
	local cleared = {
		self.displayHeader, self.displayBox,
		self.barEnabledRow, self.lockRow,
		self.iconGapRow, self.iconSizeRow, self.textSizeRow, self.tipRow, self.swapRow,
		self.barEnabledCheck, self.lockCheck, self.tipCheck, self.swapCheck, self.resetBtn,
		self.iconGapSlider, self.iconSizeSlider, self.textSizeSlider,
		self.monHeader, self.listBox, self.formBox, self.formArea,
		self.tabNew, self.tabDetail,
		self.itemSecRow, self.spellSecRow, self.otherSecRow,
		self.itemIDRow, self.itemNameRow, self.clickRow,
		self.spellIDRow, self.spellNameRow, self.durRow, self.cdRow,
		self.enabledRow, self.procRow, self.iconSrcRow,
		self.itemEdit, self.itemName,
		self.spellEdit, self.spellName, self.durEdit, self.cdEdit,
		self.clickCheck, self.enabledCheck, self.procCheck,
		self.iconSrcDec, self.iconSrcBox, self.iconSrcInc,
		self.itemSlot, self.spellSlot, self.addBtn, self.delBtn,
		self.upBtn, self.downBtn,
		self.ioArea, self.ioExpHead, self.ioExpLabel, self.ioExportBtn, self.ioExpBox,
		self.ioImpHead, self.ioImpLabel,
		self.ioRuleRow, self.ioRuleDec, self.ioRuleBox, self.ioRuleInc,
		self.ioPasteBox, self.ioBtnRow, self.ioImpBtn, self.ioResult,
	}
	-- 注：标签（CreateLabel）都只在创建时锚一次，不进这张表
	for i = 1, #cleared do cleared[i]:ClearAllPoints() end

	local W = self.content:GetWidth()
	if W < 100 then W = 520 end
	local boxW = W - 8
	local formW = boxW - LIST_W - BOX_GAP
	local rowW = formW - PAD * 2 - ICON_COL
	local fullW = rowW + ICON_COL
	local selW = SEL_BTN_W * 2 + SEL_GAP * 2

	local ctrlX = CtrlX({
		self.itemIDLabel, self.itemNameLabel, self.clickLabel,
		self.spellIDLabel, self.spellNameLabel, self.durLabel, self.cdLabel,
	})
	local editW = formW - PAD - ICON_COL - ctrlX - EDIT_RIGHT
	local dispCtrlX = CtrlX({
		self.barEnabledLabel, self.lockLabel, self.iconGapLabel, self.iconSizeLabel,
		self.textSizeLabel, self.tipLabel, self.swapLabel,
	}) + DISP_CTRL_DX

	local entries = ns.db.entries
	local displayH = PAD * 2 + DISP_ROWS * DISP_ROW_H
	local formH = PAD * 2 + 3 * SEC_ROW_H + 2 * SEC_IN_GAP + 11 * ROW_H
	local listH = PAD * 2 + math.min(math.max(#entries, 1), LIST_VISIBLE) * LIST_ROW_H
	local monH = math.max(formH, listH) + MON_EXTRA_H

	self.displayHeader:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -TOP_DY)
	self.displayBox:SetPoint("TOPLEFT", self.displayHeader, "BOTTOMLEFT", 0, -TITLE_TO_BOX)
	self.displayBox:SetSize(boxW, displayH)
	local dispRows = {
		self.barEnabledRow, self.lockRow, self.iconGapRow, self.iconSizeRow,
		self.textSizeRow, self.tipRow, self.swapRow,
	}
	for i = 1, #dispRows do
		dispRows[i]:SetWidth(boxW - PAD * 2)
		if i == 1 then
			dispRows[i]:SetPoint("TOPLEFT", self.displayBox, "TOPLEFT", PAD, -PAD)
		else
			dispRows[i]:SetPoint("TOPLEFT", dispRows[i - 1], "BOTTOMLEFT", 0, 0)
		end
	end
	local dispCheckX = dispCtrlX - CheckInset(CHECK_SIZE)
	self.barEnabledCheck:SetPoint("LEFT", self.barEnabledRow, "LEFT", dispCheckX, 0)
	self.lockCheck:SetPoint("LEFT", self.lockRow, "LEFT", dispCheckX, 0)
	self.tipCheck:SetPoint("LEFT", self.tipRow, "LEFT", dispCheckX, 0)
	self.swapCheck:SetPoint("LEFT", self.swapRow, "LEFT", dispCheckX, 0)
	self.resetBtn:SetPoint("LEFT", self.lockCheck, "RIGHT", BTN_GAP, 0)
	local dispSliders = { self.iconGapSlider, self.iconSizeSlider, self.textSizeSlider }
	for i = 1, #dispSliders do
		dispSliders[i]:SetPoint("LEFT", dispRows[i + 2], "LEFT", dispCtrlX, 0)
	end

	self.monHeader:SetPoint("TOPLEFT", self.displayBox, "BOTTOMLEFT", 0, -SEC_GAP)
	self.listBox:SetPoint("TOPLEFT", self.monHeader, "BOTTOMLEFT", 0, -TITLE_TO_BOX)
	self.listBox:SetSize(LIST_W, monH)
	self.formBox:SetPoint("TOPLEFT", self.listBox, "TOPRIGHT", BOX_GAP, 0)
	self.formBox:SetSize(formW, monH)

	-- 页签自右向左排：数据导入 | 新建数据 | 详情
	self.tabImport:SetWidth(self.tabImport.text:GetStringWidth() + TAB_TEXT_PAD)
	self.tabImport:SetPoint("BOTTOMRIGHT", self.formBox, "TOPRIGHT", TAB_SHIFT, 0)
	self.tabNew:SetWidth(self.tabNew.text:GetStringWidth() + TAB_TEXT_PAD)
	self.tabNew:SetPoint("BOTTOMRIGHT", self.tabImport, "BOTTOMLEFT", -TAB_GAP, 0)
	self.tabDetail:SetWidth(self.tabDetail.text:GetStringWidth() + TAB_TEXT_PAD)
	self.tabDetail:SetPoint("BOTTOMRIGHT", self.tabNew, "BOTTOMLEFT", -TAB_GAP, 0)

	self.formArea:SetPoint("TOPLEFT", self.formBox, "TOPLEFT", PAD, -PAD)
	self.formArea:SetSize(formW - PAD * 2, formH - PAD * 2)

	-- 数据导入这一页：与表单同尺寸同位置，两块互斥显示
	local ioW = formW - PAD * 2
	self.ioArea:SetPoint("TOPLEFT", self.formBox, "TOPLEFT", PAD, -PAD)
	self.ioArea:SetSize(ioW, formH - PAD * 2)

	self.ioExpHead:SetPoint("TOPLEFT", self.ioArea, "TOPLEFT", 0, 0)
	self.ioExpHead:SetWidth(ioW)
	self.ioExpLabel:SetPoint("LEFT", self.ioExpHead, "LEFT", 0, 0)
	self.ioExportBtn:SetPoint("RIGHT", self.ioExpHead, "RIGHT", 0, 0)
	self.ioExpBox:SetPoint("TOPLEFT", self.ioExpHead, "BOTTOMLEFT", OTHER_LABEL_DX, -6)
	self.ioExpBox:SetWidth(ioW - OTHER_LABEL_DX)

	-- ★ 锚在导出标题上、别锚导出框（框左缩进 10，锚它会把整段带着右移）
	self.ioImpHead:SetPoint("TOPLEFT", self.ioExpHead, "BOTTOMLEFT", 0, -(6 + IO_TEXT_H + 12))
	self.ioImpHead:SetWidth(ioW)
	self.ioImpLabel:SetPoint("LEFT", self.ioImpHead, "LEFT", 0, 0)

	-- 规则选择控件定宽 200，右端贴区块右缘
	local selBoxW = IO_SEL_W - selW
	local selX = ioW - IO_SEL_W
	self.ioRuleRow:SetPoint("TOPLEFT", self.ioImpHead, "BOTTOMLEFT", 0, -4)
	self.ioRuleRow:SetWidth(ioW)
	self.ioRuleDec:SetPoint("LEFT", self.ioRuleRow, "LEFT", selX, 0)
	self.ioRuleBox:SetWidth(selBoxW)
	self.ioRuleBox:SetPoint("LEFT", self.ioRuleDec, "RIGHT", SEL_GAP, 0)
	self.ioRuleInc:SetPoint("LEFT", self.ioRuleBox, "RIGHT", SEL_GAP, 0)

	self.ioPasteBox:SetPoint("TOPLEFT", self.ioRuleRow, "BOTTOMLEFT", OTHER_LABEL_DX, -8)
	self.ioPasteBox:SetWidth(ioW - OTHER_LABEL_DX)

	-- 框右缘就是区块右缘 ⇒ 行右端天然对齐
	self.ioBtnRow:SetPoint("TOPRIGHT", self.ioPasteBox, "BOTTOMRIGHT", 0, -2)
	self.ioBtnRow:SetWidth(ioW)
	self.ioImpBtn:SetPoint("RIGHT", self.ioBtnRow, "RIGHT", 0, 0)
	self.ioResult:SetPoint("LEFT", self.ioBtnRow, "LEFT", OTHER_LABEL_DX, 0)

	self.itemSecRow:SetPoint("TOPLEFT", self.formArea, "TOPLEFT", 0, 0)
	self.itemSecRow:SetWidth(fullW)
	self.itemIDRow:SetPoint("TOPLEFT", self.itemSecRow, "BOTTOMLEFT", ICON_COL, 0)
	self.itemIDRow:SetWidth(rowW)
	self.itemNameRow:SetPoint("TOPLEFT", self.itemIDRow, "BOTTOMLEFT", 0, 0)
	self.itemNameRow:SetWidth(rowW)
	self.itemEdit:SetWidth(editW)
	self.itemName:SetWidth(editW)
	self.itemEdit:SetPoint("LEFT", self.itemIDRow, "LEFT", ctrlX, 0)
	self.itemName:SetPoint("LEFT", self.itemNameRow, "LEFT", ctrlX, 0)
	self.clickRow:SetPoint("TOPLEFT", self.itemNameRow, "BOTTOMLEFT", 0, 0)
	self.clickRow:SetWidth(rowW)
	self.clickCheck:SetPoint("LEFT", self.clickRow, "LEFT", ctrlX + EDIT_DX - CheckInset(CHECK_SIZE), 0)
	self.itemSlot:SetPoint("TOPLEFT", self.itemIDRow, "TOPLEFT", -ICON_COL, 0)

	self.spellSecRow:SetPoint("TOPLEFT", self.clickRow, "BOTTOMLEFT", -ICON_COL, -SEC_IN_GAP)
	self.spellSecRow:SetWidth(fullW)
	self.spellIDRow:SetPoint("TOPLEFT", self.spellSecRow, "BOTTOMLEFT", ICON_COL, 0)
	self.spellIDRow:SetWidth(rowW)
	self.spellNameRow:SetPoint("TOPLEFT", self.spellIDRow, "BOTTOMLEFT", 0, 0)
	self.spellNameRow:SetWidth(rowW)
	self.durRow:SetPoint("TOPLEFT", self.spellNameRow, "BOTTOMLEFT", 0, 0)
	self.durRow:SetWidth(rowW)
	self.cdRow:SetPoint("TOPLEFT", self.durRow, "BOTTOMLEFT", 0, 0)
	self.cdRow:SetWidth(rowW)
	self.spellEdit:SetWidth(editW)
	self.spellName:SetWidth(editW)
	self.durEdit:SetWidth(editW)
	self.cdEdit:SetWidth(editW)
	self.spellEdit:SetPoint("LEFT", self.spellIDRow, "LEFT", ctrlX, 0)
	self.spellName:SetPoint("LEFT", self.spellNameRow, "LEFT", ctrlX, 0)
	self.durEdit:SetPoint("LEFT", self.durRow, "LEFT", ctrlX, 0)
	self.cdEdit:SetPoint("LEFT", self.cdRow, "LEFT", ctrlX, 0)
	self.spellSlot:SetPoint("TOPLEFT", self.spellIDRow, "TOPLEFT", -ICON_COL, 0)

	-- ★ 「其他设置」组没有图标列（整行贴分组左端），但控件要跟上面两组落在同一条竖线上 ⇒
	--   列位里补一个 ICON_COL 的行首偏移
	self.otherSecRow:SetPoint("TOPLEFT", self.cdRow, "BOTTOMLEFT", -ICON_COL, -SEC_IN_GAP)
	self.otherSecRow:SetWidth(fullW)
	local otherX = ICON_COL + ctrlX + EDIT_DX
	self.enabledRow:SetPoint("TOPLEFT", self.otherSecRow, "BOTTOMLEFT", 0, 0)
	self.enabledRow:SetWidth(fullW)
	self.enabledCheck:SetPoint("LEFT", self.enabledRow, "LEFT", otherX - CheckInset(CHECK_SIZE), 0)
	self.procRow:SetPoint("TOPLEFT", self.enabledRow, "BOTTOMLEFT", 0, 0)
	self.procRow:SetWidth(fullW)
	self.procCheck:SetPoint("LEFT", self.procRow, "LEFT", otherX - CheckInset(CHECK_SIZE), 0)
	self.iconSrcRow:SetPoint("TOPLEFT", self.procRow, "BOTTOMLEFT", 0, 0)
	self.iconSrcRow:SetWidth(fullW)
	self.iconSrcDec:SetPoint("LEFT", self.iconSrcRow, "LEFT", otherX - SEL_ART_INSET, 0)
	self.iconSrcBox:SetWidth(editW - EDIT_DX - selW)
	self.iconSrcBox:SetPoint("LEFT", self.iconSrcDec, "RIGHT", SEL_GAP, 0)
	self.iconSrcInc:SetPoint("LEFT", self.iconSrcBox, "RIGHT", SEL_GAP, 0)

	self.addBtn:SetPoint("BOTTOMRIGHT", self.formBox, "BOTTOMRIGHT", -PAD, PAD)
	self.delBtn:SetPoint("BOTTOMRIGHT", self.formBox, "BOTTOMRIGHT", -PAD, PAD)
	self.upBtn:SetPoint("BOTTOMLEFT", self.formBox, "BOTTOMLEFT", PAD, PAD)
	self.downBtn:SetPoint("BOTTOMLEFT", self.upBtn, "BOTTOMRIGHT", BTN_GAP, 0)

	-- 滚动范围罩住全部条目；行摆在哪由 ReloadList 按滚动偏移算
	self.listContent:SetHeight(math.max(#entries, 1) * LIST_ROW_H)

	self.content:SetHeight(TOP_DY + TITLE_H + TITLE_TO_BOX + displayH
		+ SEC_GAP + TITLE_H + TITLE_TO_BOX + monH + BOTTOM)
end

function Options:Sync()
	self.barEnabledCheck:SetChecked(ns.db.enabled ~= false)
	self.lockCheck:SetChecked(ns.db.locked)
	self.tipCheck:SetChecked(ns.db.tooltip)
	self.swapCheck:SetChecked(ns.db.swapTrinkets)
	-- ★ SetValue 会触发 OnValueChanged：filling 这一段就是"这是回填、不是用户改的"
	self.filling = true
	self.iconGapSlider.slider:SetValue(ns.db.gap)
	self.iconSizeSlider.slider:SetValue(ns.db.slotSize)
	self.textSizeSlider.slider:SetValue(ns.db.fontSize)
	self.filling = nil

	local entries = ns.db.entries
	self:ReloadList()
	self.emptyHint:SetShown(#entries == 0)

	self.iconSrcBox.text:SetText(IconSrcText(self.iconSource))

	local isNew = self.mode == "new"
	local isIO = self.mode == "io"
	local hasEntry = not isNew and self.editing ~= nil
	SetTabSelected(self.tabNew, isNew)
	SetTabSelected(self.tabDetail, not isNew and not isIO)
	SetTabSelected(self.tabImport, isIO)

	-- 空白详情整块表单都不画（新建页或有选中条目才画）
	self.formArea:SetShown(isNew or hasEntry)
	self.ioArea:SetShown(isIO)
	self.addBtn:SetShown(isNew)
	self.delBtn:SetShown(hasEntry)
	self.upBtn:SetShown(hasEntry)
	self.downBtn:SetShown(hasEntry)
	self.upBtn:SetEnabled(hasEntry and self.editing > 1)
	self.downBtn:SetEnabled(hasEntry and self.editing < #entries)
	if isIO then
		self:UpdateImportState()
		self.ioExportBtn:SetEnabled(#entries > 0)
	end
end

function Options:Reload()
	if not self.content then return end
	self:Layout()
	self:Sync()
end

function Options:ReloadIfOpen()
	if self.content and self.panel:IsShown() then self:Reload() end
end

function Options:Open()
	Settings.OpenToCategory(self.category:GetID())
end

Options:Build()

local category = Settings.RegisterCanvasLayoutCategory(Options.panel, ADDON_NAME)
Settings.RegisterAddOnCategory(category)
Options.category = category
