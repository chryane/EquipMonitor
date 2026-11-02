--[[ Transfer.lua - 监控列表的导出 / 导入串
	 变长整数 + 位打包 + Base64（不套压缩：一条 11 字节，deflate 头比它自己还长）
]]

local ADDON_NAME, ns = ...

local FORMAT = 1
local MAX_ENTRIES = 200

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_VAL = {}
for i = 1, #B64 do B64_VAL[B64:sub(i, i)] = i - 1 end

local function Base64(bytes)
	local out, i, n = {}, 1, #bytes
	while i <= n do
		local b1, b2, b3 = bytes[i], bytes[i + 1], bytes[i + 2]
		local c1 = math.floor(b1 / 4)
		local c2 = (b1 % 4) * 16 + math.floor((b2 or 0) / 16)
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1)
		out[#out + 1] = B64:sub(c2 + 1, c2 + 1)
		if b2 then
			local c3 = (b2 % 16) * 4 + math.floor((b3 or 0) / 64)
			out[#out + 1] = B64:sub(c3 + 1, c3 + 1)
		end
		if b3 then out[#out + 1] = B64:sub(b3 % 64 + 1, b3 % 64 + 1) end
		i = i + 3
	end
	return table.concat(out)
end

local function Unbase64(s)
	s = (s or ""):gsub("%s+", "")
	-- 标准 Base64 的长度模 4 不可能余 1 ⇒ 直接判坏串，别让半截串混过去
	if s == "" or #s % 4 == 1 then return nil end
	local out, acc, bits = {}, 0, 0
	for i = 1, #s do
		local v = B64_VAL[s:sub(i, i)]
		if not v then return nil end
		acc = acc * 64 + v
		bits = bits + 6
		if bits >= 8 then
			bits = bits - 8
			local b = math.floor(acc / 2 ^ bits)
			out[#out + 1] = b
			acc = acc - b * 2 ^ bits
		end
	end
	return out
end

local function PutVarint(out, n)
	repeat
		local rest = math.floor(n / 128)
		out[#out + 1] = n - rest * 128 + (rest > 0 and 128 or 0)
		n = rest
	until n == 0
end

local function TakeVarint(bytes, pos, last)
	local n, mul = 0, 1
	while true do
		if pos > last then return nil end
		local b = bytes[pos]
		pos = pos + 1
		n = n + (b % 128) * mul
		if b < 128 then return n, pos end
		mul = mul * 128
	end
end

local function PutText(out, s)
	PutVarint(out, #s)
	for i = 1, #s do out[#out + 1] = s:byte(i) end
end

local function TakeText(bytes, pos, last)
	local len, p = TakeVarint(bytes, pos, last)
	if not len or p + len - 1 > last then return nil end
	local t = {}
	for i = p, p + len - 1 do t[#t + 1] = string.char(bytes[i]) end
	return table.concat(t), p + len
end

-- 布局：版本(1) | 条数(varint) | 每条[物品ID, 法术ID, 持续, 冷却 各 varint、标志位(1)、(名字, 法术名)]… | 校验和(1)
function ns.Encode(entries)
	local out = { FORMAT }
	PutVarint(out, #entries)
	for i = 1, #entries do
		local e = entries[i]
		PutVarint(out, e.itemID or 0)
		PutVarint(out, e.spellID or 0)
		PutVarint(out, e.duration or 0)
		PutVarint(out, e.cooldown or 0)
		local f = 0
		if e.enabled ~= false then f = f + 1 end
		if e.clickable then f = f + 2 end
		if e.procOnly then f = f + 4 end
		if e.iconSource == ns.ICON_SPELL then f = f + 8 end
		if e.itemName then f = f + 16 end
		if e.spellName then f = f + 32 end
		out[#out + 1] = f
		if e.itemName then PutText(out, e.itemName) end
		if e.spellName then PutText(out, e.spellName) end
	end
	local sum = 0
	for i = 1, #out do sum = (sum * 31 + out[i]) % 256 end
	out[#out + 1] = sum
	return Base64(out)
end

-- 返回 entries 数组；坏串一律 nil（调用方据此提示，绝不半截写存档）
function ns.Decode(str)
	local bytes = Unbase64(str)
	if not bytes or #bytes < 3 then return nil end
	local last = #bytes - 1
	local sum = 0
	for i = 1, last do sum = (sum * 31 + bytes[i]) % 256 end
	if bytes[#bytes] ~= sum or bytes[1] ~= FORMAT then return nil end
	local count, pos = TakeVarint(bytes, 2, last)
	-- ★ 每一步都得先判"被截断"，否则 nil 继续往下传会变成 Lua 报错而不是"坏串"
	if not count or count > MAX_ENTRIES then return nil end
	local entries = {}
	for k = 1, count do
		local itemID, p1 = TakeVarint(bytes, pos, last)
		if not p1 then return nil end
		local spellID, p2 = TakeVarint(bytes, p1, last)
		if not p2 then return nil end
		local duration, p3 = TakeVarint(bytes, p2, last)
		if not p3 then return nil end
		local cooldown, p4 = TakeVarint(bytes, p3, last)
		if not p4 or p4 > last then return nil end
		local f = bytes[p4]
		if itemID <= 0 or spellID <= 0 then return nil end
		local e = {
			itemID = itemID, spellID = spellID,
			duration = duration, cooldown = cooldown,
			enabled = f % 2 == 1,
			clickable = math.floor(f / 2) % 2 == 1,
			procOnly = math.floor(f / 4) % 2 == 1,
			iconSource = math.floor(f / 8) % 2 == 1 and ns.ICON_SPELL or ns.ICON_ITEM,
		}
		pos = p4 + 1
		if math.floor(f / 16) % 2 == 1 then
			e.itemName, pos = TakeText(bytes, pos, last)
			if not e.itemName then return nil end
		end
		if math.floor(f / 32) % 2 == 1 then
			e.spellName, pos = TakeText(bytes, pos, last)
			if not e.spellName then return nil end
		end
		entries[k] = e
	end
	return entries
end
