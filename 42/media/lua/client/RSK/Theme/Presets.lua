-- RSK.Theme: colour presets (D-16, D-36) and base sizes (Stile_UI, values at 1080p: D-49).
RSK = RSK or {}
RSK.Theme = RSK.Theme or {}
local T = RSK.Theme

T.COLOR_TOKENS = { "bg", "panel", "panel2", "sel", "line", "text", "muted", "accent", "ink", "danger", "ok", "warn" }
T.DEFAULT_PRESET = "ruggine"
T.PRESET_ORDER = { "ruggine", "militare", "notte" }

T.presets = {
    ruggine = { bg = "#121110", panel = "#1b1a18", panel2 = "#25231f", sel = "#2e2a24", line = "#3a3632",
        text = "#ebe5d9", muted = "#a39b8f", accent = "#d48c3c", ink = "#16120d",
        danger = "#d4553f", ok = "#93b36f", warn = "#e2b340" },
    militare = { bg = "#0f120e", panel = "#181c16", panel2 = "#21271e", sel = "#283023", line = "#36402f",
        text = "#e4e8d9", muted = "#9ca58e", accent = "#bcc56c", ink = "#141710",
        danger = "#d9673f", ok = "#7fb56a", warn = "#d9c25a" },
    notte = { bg = "#0c1013", panel = "#131a1f", panel2 = "#1b242b", sel = "#20303a", line = "#2d3943",
        text = "#dde6ec", muted = "#8f9daa", accent = "#5fb6c6", ink = "#0b1418",
        danger = "#e5764f", ok = "#7cb87d", warn = "#e6c55a" },
}

-- Sizes in px at "text size" level 2, scaled by T.px (D-107).
T.base = {
    radius = { ctrl = 3, win = 4 },
    border = 1,
    space = { xs = 4, s = 8, m = 12, l = 16, xl = 24 },
    h = { button = 44, title = 44, loadBar = 36, row = 52, rowSub = 40, tab = 40, label = 26, stepper = 20 },
    icon = { item = 42, slot = 64, tooltip = 56, button = 20, buttonBox = 44, status = 18 },
    bar = { cond = 5, health = 8, load = 10, tabLine = 2 },
    w = { tooltip = 270, equip = 500, slotCol = 70, colCategory = 110, colWeight = 52, colContainers = 36 },
    -- Inventory/container window (Stile_UI, Inventory mockup): row margins, column header,
    -- container column (36 boxes in 44, icon 22; D-63), icon inside the 42 box, title 36 with
    -- buttons 28 and icons 14 (D-64), load band 28 with bar 4 (D-65), stacks without arrow (D-66).
    inv = { padL = 8, padR = 12, gap = 8, header = 32, containerCol = 44, containerIcon = 22, iconInner = 32, subIndent = 24,
        subIcon = 28, badgeH = 20, loadBar = 4, loadPad = 14, titleH = 36, loadH = 28, titleBtn = 28, titleIcon = 14, titlePad = 6, status = 14,
        searchRow = 57, searchField = 36, searchPad = 14, -- search row (D-74)
        -- row bar (D-101); cards of stack and group children (D-103): indent 42, right margin 8,
        -- 4 above the first and below the last, icon 32 with image 21, inner margins 4 / 8
        rowBar = 3, cardL = 42, cardR = 8, cardInset = 4, cardIcon = 32, cardInner = 21, cardPadL = 4, cardPadR = 8 },
    -- Item tooltip (Stile_UI, D-17, D-72): 270 wide, margin 10, gap 8, icon 56 with image 36;
    -- bars [label <= 84][bar >= 40, 6 tall][value >= 32, always whole], mouse offset 24.
    tip = { pad = 10, gap = 8, headGap = 10, nameGap = 2, iconInner = 36, barLabel = 84, barValMin = 32, barMin = 40, barH = 6, rowGap = 4, mouse = 24 },
    -- Bar thresholds (Stile_UI): ok >= 60%, accent >= 30%, danger below; load: danger above 80% (D-32)
    threshold = { condOk = 0.6, condMid = 0.3, loadDanger = 0.8 },
}

-- Item colour groups (D-99), the same for every theme; row tint and children cards 35% like the
-- tooltip band, selection 45% (D-110); icon box bg 55% (D-100); tooltip band 35% over bg (D-104).
T.GROUP_HEX = { food = "#5fa79a", med = "#c98aa6", weapon = "#8e9bb0", tool = "#b8a07a",
    cloth = "#6f8fd0", read = "#a38bd6", cont = "#a8836a",
    animal = "#b9786a", leisure = "#7aa37a", misc = "#9b968e" } -- D-114
T.groupAlpha = { row = 0.35, sel = 0.45, child = 0.35, well = 0.55, tipBand = 0.35, tipWell = 0.45, tipSub = 0.8,
    track = 0.08, childSep = 0.10 }

-- States and opacity (D-50): hover = sel with alpha 0.6 over the background; disabled = 0.35.
T.alpha = { hover = 0.6, disabled = 0.35, window = 1.0 }

-- Typographic roles (Stile_UI, D-106). family = key in T.FONT_FILES.
T.fonts = {
    screenTitle = { family = "semibold", size = 36, upper = true },
    menuTitle   = { family = "semibold", size = 48, upper = true, tracking = 0.06 }, -- pause and menu screens (D-148)
    menuButton  = { family = "semibold", size = 19, upper = true, tracking = 0.06 }, -- bottom bar buttons (D-148, D-20)
    windowTitle = { family = "semibold", size = 21 },
    invTitle    = { family = "semibold", size = 18 },
    body        = { family = "regular",  size = 16 },
    row         = { family = "regular",  size = 17 },
    itemName    = { family = "semibold", size = 17 },
    label       = { family = "semibold", size = 13, upper = true, tracking = 0.12 },
    button      = { family = "semibold", size = 16, upper = true },
    number      = { family = "semibold", size = 20 },
    rowSmall    = { family = "regular",  size = 15 },
    rowCard     = { family = "regular",  size = 16 }, -- name in the children cards (D-103)
    qty         = { family = "regular",  size = 14 },
    badge       = { family = "semibold", size = 12, upper = true, tracking = 0.08 },
    tipText     = { family = "regular",  size = 14 },
    tipSub      = { family = "regular",  size = 13 },
    -- M2 info fields: same sizes as the tip* roles, but SemiBold for readability (D-98).
    infoLabel   = { family = "semibold", size = 13 },
    infoValue   = { family = "semibold", size = 14 },
    infoText    = { family = "semibold", size = 15 },
}
-- Fira bitmap atlases (D-106, D-108): media/fonts/rsk/<prefix><size>.fnt + _0.png; sizes in FontSizes.lua.
T.FONT_DIR = "media/fonts/rsk/"
T.FONT_FILES = { regular = "rsk_regular", semibold = "rsk_semibold" }
