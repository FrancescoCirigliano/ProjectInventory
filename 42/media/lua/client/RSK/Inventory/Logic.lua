-- RSK.Inventory.Logic - inventory reskin calculations with no engine dependencies (testable, T-17).
-- Sizes in 1080p units (T.base.inv, T.base.w); the drawing code converts them with T.px (D-49).
require "RSK/UI/Logic"

RSK = RSK or {}
RSK.Inventory = RSK.Inventory or {}
RSK.Inventory.Logic = RSK.Inventory.Logic or {}
local IL = RSK.Inventory.Logic

-- Load bar (D-22, D-32): bar fraction 0..1, colour, "weight" and "capacity" texts.
-- Above 80% only the colour changes; the player inventory can exceed capacity (full bar).
function IL.loadInfo(weight, cap)
    weight = tonumber(weight) or 0
    cap = tonumber(cap)
    local ratio = (cap and cap > 0) and weight / cap or 0
    local frac = ratio
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    return {
        frac = frac,
        tok = RSK.UI.Logic.barToken("load", ratio),
        load = string.format("%.2f", weight),
        cap = cap and string.format("%.2f", cap) or nil,
    }
end

-- List columns: [pad 8][icon 42][gap][name ...][category 110][gap][weight 52][pad 12] (stacks without arrow, D-66).
-- Returns, in 1080p units: column2 (name start - gap, as vanilla writes at column2+8),
-- icon x, minimum width of the category+weight column (typeHeader).
function IL.columns(base, dims)
    local inv, w = base.inv, base.w
    local iconX = inv.padL
    local column2 = iconX + (dims and dims.item or base.icon.item)
    local typeMin = inv.gap + w.colCategory + inv.gap + w.colWeight + inv.padR
    return { iconX = iconX, column2 = column2, nameX = column2 + inv.gap, typeMin = typeMin }
end

-- Scrollbar thumb (full travel, no arrows): trackH = bar height, view = visible
-- rows, content = rows height, pos 0..1. Returns thumb y and height (minimum minH).
function IL.scrollThumb(trackH, view, content, pos, minH)
    if trackH <= 0 or content <= 0 then return 0, 0 end
    local h = math.floor(trackH * math.min(1, view / content) + 0.5)
    if h < minH then h = math.min(minH, trackH) end
    if pos < 0 then pos = 0 elseif pos > 1 then pos = 1 end
    return math.floor((trackH - h) * pos + 0.5), h
end

-- Icon size from the settings (D-125): row/icon; card, indent and badges in proportion to the icon.
-- "medium" = theme sizes (Stile_UI). Unknown value -> medium. 1080p units.
IL.ICON_ORDER = { "small", "medium", "large" }
IL.ICON_SIZES = { small = { row = 40, item = 32 }, medium = { row = 52, item = 42 }, large = { row = 64, item = 52 } }
function IL.rowDims(base, sizeId)
    local s = IL.ICON_SIZES[sizeId] or IL.ICON_SIZES.medium
    local inv = base.inv
    local f = s.item / base.icon.item
    local function r(v) return math.floor(v * f + 0.5) end
    return { id = IL.ICON_SIZES[sizeId] and sizeId or "medium", row = s.row, item = s.item,
        iconInner = r(inv.iconInner), cardL = r(inv.cardL), cardIcon = r(inv.cardIcon), cardInner = r(inv.cardInner),
        badge = r(12) }
end

-- Hidden equipped items (D-125): removes in place the equipped stacks of itemslist. Returns how many were removed.
function IL.dropEquipped(list)
    local keep = {}
    for _, v in ipairs(list) do if not v.equipped then keep[#keep + 1] = v end end
    local n = #list - #keep
    if n == 0 then return 0 end
    for i = 1, #list do list[i] = keep[i] end
    return n
end

-- A row of vanilla self.items: a stack (table with .items, first element repeated as header)
-- or a single item of an expanded stack. isItem(e) -> true if it is an InventoryItem.
function IL.rowInfo(entry, isItem)
    if isItem(entry) then return { item = entry, sub = true, count = 1 } end
    local n = (entry.count or 2) - 1
    return { item = entry.items[1], group = entry, sub = false, count = n, stack = n > 1 }
end

-- Visible rows of the vanilla pane: row i sits at headerH + (i-1)*rowH in the content,
-- yScroll <= 0 (Java scrolling). Empty list -> 1, 0.
function IL.visibleRows(yScroll, viewH, headerH, rowH, n)
    if n <= 0 or rowH <= 0 then return 1, 0 end
    local off = -(yScroll or 0)
    local first = math.floor(off / rowH) + 1
    local last = math.ceil((viewH - headerH + off) / rowH)
    if first < 1 then first = 1 end
    if last > n then last = n end
    return first, last
end

function IL.qtyText(n)
    if (n or 1) > 1 then return "\195\151" .. tostring(n) end -- "×N"
    return nil
end

function IL.weightText(w) return string.format("%.2f", tonumber(w) or 0) end

-- Line between equipped and non-equipped items (as in vanilla): above stack i if the state changes
-- from the previous stack. prevEquipped nil = no stack before.
function IL.equipDivider(equipped, prevEquipped)
    return prevEquipped ~= nil and (equipped and true or false) ~= (prevEquipped and true or false)
end

-- Name room: available space goes first to quantity, badge, states and status icon, the rest to the name.
-- widths = { qty, badge, state, status } (0 if absent), gap between elements. Returns the maximum name width.
function IL.nameRoom(avail, widths, gap)
    local extra = 0
    for _, k in ipairs({ "qty", "badge", "state", "status" }) do
        local v = widths[k] or 0
        if v > 0 then extra = extra + v + gap end
    end
    local room = avail - extra
    if room < 0 then room = 0 end
    return room
end

-- ---------------------------------------------------------------- colour groups (D-99, D-114)
-- Vanilla display category -> group. "<Base>Weapon" (ToolWeapon, CookingWeapon...) follows the base.
IL.GROUP_ORDER = { "food", "med", "weapon", "tool", "cloth", "read", "cont", "animal", "leisure", "misc" }
IL.CAT_GROUP = {
    Food = "food", Water = "food", WaterContainer = "food", Cooking = "food",
    FirstAid = "med", Bandage = "med", Wound = "med",
    Weapon = "weapon", WeaponCrafted = "weapon", WeaponImprovised = "weapon", WeaponPart = "weapon",
    BrokenWeapon = "weapon", Ammo = "weapon", Explosives = "weapon",
    Tool = "tool", Material = "tool", Electronics = "tool", Household = "tool", Gardening = "tool",
    Camping = "tool", Security = "tool", VehicleMaintenance = "tool",
    Paint = "tool", FireSource = "tool", LightSource = "tool", Devices = "tool", Communications = "tool",
    RecipeResource = "tool",
    Clothing = "cloth", Accessory = "cloth", ProtectiveGear = "cloth", AlarmClock = "cloth",
    Literature = "read", SkillBook = "read", Cartography = "read",
    Bag = "cont", Container = "cont",
    -- D-114: animals, hunting and fishing
    Animal = "animal", AnimalPart = "animal", Corpse = "animal", Bug = "animal", Tail = "animal", Ears = "animal",
    Eye = "animal", Fishing = "animal", Trapping = "animal", Badger = "animal", Bear = "animal", Beaver = "animal",
    Bunny = "animal", Dog = "animal", Duck = "animal", Fox = "animal", Frog = "animal", Hedgehog = "animal",
    Mole = "animal", Raccoon = "animal", Spider = "animal", Squirrel = "animal",
    -- D-114: leisure and personal items
    Entertainment = "leisure", Instrument = "leisure", Sports = "leisure", Memento = "leisure", Teddy = "leisure",
    Goblin = "leisure", Appearance = "leisure", MakeUp = "leisure",
    -- D-114: misc
    Junk = "misc", Generic = "misc", Item = "misc", Unknown = "misc", Furniture = "misc",
}
-- Categories never shown in the inventory: no colour.
IL.CAT_HIDDEN = { Hidden = true, ZedDmg = true }

-- Item group: from the category, otherwise "cont" if it is a container, otherwise "misc" (also
-- categories added by other mods, D-114); nil only for an empty or hidden category.
function IL.groupOf(cat, isContainer)
    cat = tostring(cat or "")
    if cat == "" or IL.CAT_HIDDEN[cat] then return isContainer and "cont" or nil end
    local g = IL.CAT_GROUP[cat]
    if not g then
        local base = cat:match("^(.+)Weapon$")
        if base then g = IL.CAT_GROUP[base] end
    end
    if not g and isContainer then g = "cont" end
    return g or "misc"
end

-- Mix of two colours {r,g,b} (0..1): k = 0 -> a, 1 -> b. Tooltip band (D-104).
function IL.mix(a, b, k)
    return { r = a.r + (b.r - a.r) * k, g = a.g + (b.g - a.g) * k, b = a.b + (b.b - a.b) * k, a = 1 }
end

-- ---------------------------------------------------------------- states in brackets (D-102)
IL.STATE_ORDER = { "broken", "rotten", "burnt", "stale", "frozen", "wet", "cooked" }

-- Vanilla "Name (a, b)" (IGUI_FoodNaming / IGUI_ClothingNaming = "%2 (%1)") -> "Name", { "a", "b" }.
function IL.splitName(name)
    name = tostring(name or "")
    local base, inside = name:match("^(.-)%s+%((.-)%)$")
    if not base or base == "" then return name, {} end
    local words = {}
    for w in inside:gmatch("[^,]+") do
        w = w:match("^%s*(.-)%s*$")
        if w ~= "" then words[#words + 1] = w end
    end
    return base, words
end

-- Row states: flags = { key = true } read from the item; words = vanilla words of the name;
-- known = { word -> key | false (to omit) }. Returns the keys in order and the extra words.
function IL.stateKeys(flags, words, known)
    local on, extras = {}, {}
    for k, v in pairs(flags or {}) do if v then on[k] = true end end
    for _, w in ipairs(words or {}) do
        local k = known and known[w]
        if k then on[k] = true elseif k == nil then extras[#extras + 1] = w end
    end
    local keys = {}
    for _, k in ipairs(IL.STATE_ORDER) do if on[k] then keys[#keys + 1] = k end end
    return keys, extras
end

-- "(broken, rotten, extra)" or nil. textOf(key) -> text; extra words get a lowercase initial.
function IL.stateText(keys, extras, textOf)
    local t = {}
    for _, k in ipairs(keys or {}) do t[#t + 1] = textOf(k) end
    for _, w in ipairs(extras or {}) do t[#t + 1] = w:sub(1, 1):lower() .. w:sub(2) end
    if #t == 0 then return nil end
    return "(" .. table.concat(t, ", ") .. ")"
end

-- ---------------------------------------------------------------- row bar (D-101)
-- kind = "qty" (quantity) | "cond" (condition) | vanilla progress token. Full/intact -> nil,
-- unless always (condition, weapons only, always visible: D-115).
function IL.rowBar(kind, frac, always)
    if kind == nil or frac == nil then return nil end
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    if not always and (kind == "qty" or kind == "cond") and frac >= 1 then return nil end
    local tok = kind
    if kind == "qty" then tok = "muted" elseif kind == "cond" then tok = RSK.UI.Logic.barToken("cond", frac) end
    return frac, tok
end

-- ---------------------------------------------------------------- "Equipped" group (D-103)
-- Merges in place the equipped stacks of itemslist (after vanilla sorting and repeated first
-- element) into one stack at the bottom, same format: items[1] = header, count = items + 1.
-- Returns the group stack (nil if nothing is equipped).
function IL.mergeEquipped(list, name)
    local keep, grp = {}, nil
    for _, v in ipairs(list) do
        if v.equipped then
            if not grp then
                grp = { items = { v.items[1] }, count = 1, weight = 0, equipped = true, inHotbar = false,
                    rskGroup = "equipped", name = name, cat = v.cat, invPanel = v.invPanel }
            end
            for j = 2, #v.items do grp.items[#grp.items + 1] = v.items[j] end
            grp.count = grp.count + ((v.count or 2) - 1)
            grp.weight = grp.weight + (v.weight or 0)
        else
            keep[#keep + 1] = v
        end
    end
    if not grp then return nil end
    keep[#keep + 1] = grp
    for i = 1, math.max(#list, #keep) do list[i] = keep[i] end
    return grp
end
