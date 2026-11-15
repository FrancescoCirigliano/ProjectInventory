-- RSK in-game tests (D-40). Active only with -debug, to be used on a dedicated save.
-- Excluded from the Workshop build (D-41). Run: right click in the world -> "RSK: esegui test",
-- or RSK.Tests.run() from the debug Lua console. Results in console.txt: [RSK-TEST] ...
if not isDebugEnabled() then return end

require "TimedActions/ISTimedActionQueue"
require "RSK/Core/TransferRules"
require "RSK/Core/Actions"
require "RSK/Nested/Nested"
require "RSK/Search/Search"
require "RSK/Equipment/Equipment"

RSK = RSK or {}
RSK.Tests = RSK.Tests or {}
local T = RSK.Tests
local R = RSK.TransferRules
local A = RSK.Actions
local TIMEOUT = 900 -- tick

T.list = {}
local created = {}

local function log(s) print("[RSK-TEST] " .. s) end
local function P() return getSpecificPlayer(0) end

-- ------------------------------------------------------------------ assertions
local function eq(a, b, msg)
    if a ~= b then error((msg or "valore") .. ": atteso " .. tostring(b) .. ", ottenuto " .. tostring(a)) end
end

local function desc(c)
    if not c then return "nil" end
    return A.containerName(c) .. " " .. string.format("%.2f/%d", c:getCapacityWeight(), c:getEffectiveCapacity(P()))
end

-- ------------------------------------------------------------------ creation and cleanup
local function track(it)
    if not it then error("SKIP: oggetto non creato") end
    created[#created + 1] = it
    return it
end
local function spawnIn(container, fullType) return track(container:AddItem(fullType)) end
local function spawnMany(container, fullType, n)
    local out = {}
    for i = 1, n do out[i] = spawnIn(container, fullType) end
    return out
end
local function spawnFloor(sq, fullType) return track(sq:AddWorldInventoryItem(fullType, 0.5, 0.5, 0)) end

local function cleanup()
    for i = #created, 1, -1 do
        local it = created[i]
        pcall(function()
            local wi = it:getWorldItem()
            if wi and wi:getSquare() then
                local sq = wi:getSquare()
                sq:transmitRemoveItemFromSquare(wi)
                sq:removeWorldObject(wi)
                it:setWorldItem(nil)
            end
            local c = it:getContainer()
            if c then
                c:DoRemoveItem(it)
                c:setDrawDirty(true)
            end
        end)
    end
    created = {}
    if T.reenable then
        RSK.Core.setEnabled(T.reenable, true)
        T.reenable = nil
    end
    if RSK.Nested then RSK.Nested.closeAll() end
end

-- ------------------------------------------------------------------ waits (inside the test coroutine)
local function waitQueue()
    local q = ISTimedActionQueue.getTimedActionQueue(P())
    local t = 0
    repeat
        coroutine.yield()
        t = t + 1
        if t > TIMEOUT then error("timeout: la coda delle azioni non si svuota") end
    until not q.queue or #q.queue == 0
    coroutine.yield()
end

local function waitMs(ms)
    local stop = getTimestampMs() + ms
    while getTimestampMs() < stop do coroutine.yield() end
end

-- ------------------------------------------------------------------ T-11 engine contract
-- RSK may be stricter than the engine only along the chain (the point of TransferRules);
-- on the direct destination the two predictions must match.
local function contract(items, dest)
    local p = P()
    for _, it in ipairs(items) do
        local plan = R.plan(p, { it }, dest)
        local ours = #plan.accepted == 1
        local engine = dest:isItemAllowed(it) and dest:hasRoomFor(p, it)
        local r = plan.refused[1]
        T.contracts = T.contracts + 1
        if ours and not engine then
            error("T-11 contratto: RSK accetta, il motore rifiuta " .. it:getName() .. " -> " .. desc(dest))
        end
        if not ours and engine and r and (r.reason == "tooBig" or (r.reason == "noRoom" and r.container == dest)) then
            error("T-11 contratto: RSK rifiuta (" .. r.reason .. "), il motore accetta " .. it:getName() .. " -> " .. desc(dest))
        end
    end
end

-- Transfer with contract and conservation: accepted items arrive, refused ones stay.
local function check(items, dest)
    contract(items, dest)
    local p = P()
    local src = {}
    for i, it in ipairs(items) do src[i] = it:getContainer() end
    local plan = R.plan(p, items, dest)
    local n, refused = A.transfer(p, items, dest)
    waitQueue()
    local acc = {}
    for _, it in ipairs(plan.accepted) do acc[it] = true end
    for i, it in ipairs(items) do
        if acc[it] then
            if not dest:contains(it) then error("accettato ma non arrivato: " .. it:getName() .. " -> " .. desc(dest)) end
        elseif src[i] and not src[i]:contains(it) then
            error("rifiutato ma sparito dalla sorgente: " .. it:getName())
        end
    end
    return n, refused
end

-- ------------------------------------------------------------------ scenarios
local function add(id, name, fn) T.list[#T.list + 1] = { id = id, name = name, fn = fn } end

add("T-01a", "inventario -> borsa annidata a 2 livelli", function()
    local inv = P():getInventory()
    local bag = spawnIn(inv, "Base.Bag_Schoolbag")
    local kit = spawnIn(bag:getInventory(), "Base.FirstAidKit")
    local n = check({ spawnIn(inv, "Base.Bandage") }, kit:getInventory())
    eq(n, 1, "accodati")
end)

add("T-01b", "inventario -> borsa annidata a 3 livelli", function()
    local inv = P():getInventory()
    local a = spawnIn(inv, "Base.Bag_Schoolbag")
    local b = spawnIn(a:getInventory(), "Base.Bag_Schoolbag")
    local kit = spawnIn(b:getInventory(), "Base.FirstAidKit")
    eq(check({ spawnIn(inv, "Base.Bandage") }, kit:getInventory()), 1, "accodati")
end)

add("T-01c", "fuori: dalla borsa annidata all'inventario", function()
    local inv = P():getInventory()
    local bag = spawnIn(inv, "Base.Bag_Schoolbag")
    local kit = spawnIn(bag:getInventory(), "Base.FirstAidKit")
    local b = spawnIn(kit:getInventory(), "Base.Bandage")
    eq(check({ b }, inv), 1, "accodati")
end)

add("T-02", "il kit esterno (4) ferma quello interno", function()
    local p = P()
    local outer = spawnIn(p:getInventory(), "Base.FirstAidKit")
    local inner = spawnIn(outer:getInventory(), "Base.FirstAidKit")
    spawnMany(inner:getInventory(), "Base.Bandage", 29)
    local n, refused = check(spawnMany(p:getInventory(), "Base.Bandage", 2), inner:getInventory())
    eq(n, 1, "accodati")
    eq(refused and refused.reason, "noRoom", "motivo")
    local o = outer:getInventory()
    if o:getCapacityWeight() > o:getEffectiveCapacity(p) + R.EPS then error("kit esterno oltre capienza: " .. desc(o)) end
end)

add("T-03a", "MaxItemSize: rottame di metallo nel kit da cucito", function()
    local inv = P():getInventory()
    local sew = spawnIn(inv, "Base.SewingKit")
    local n, refused = check({ spawnIn(inv, "Base.ScrapMetal") }, sew:getInventory())
    eq(n, 0, "accodati")
    eq(refused and refused.reason, "tooBig", "motivo")
end)

add("T-03b", "MaxItemSize: kit pieno troppo grande, kit vuoto entra", function()
    local inv = P():getInventory()
    local dest = spawnIn(inv, "Base.FirstAidKit")
    local empty = spawnIn(inv, "Base.FirstAidKit")
    local full = spawnIn(inv, "Base.FirstAidKit")
    spawnIn(full:getInventory(), "Base.Bandage")
    local n, refused = check({ empty, full }, dest:getInventory())
    eq(n, 1, "accodati")
    eq(refused and refused.reason, "tooBig", "motivo")
end)

add("T-04", "multiplo: si accoda solo cio' che entra, nessuno perso", function()
    local inv = P():getInventory()
    local sew = spawnIn(inv, "Base.SewingKit")
    local n = check(spawnMany(inv, "Base.Bandage", 25), sew:getInventory())
    eq(n, 20, "accodati")
    eq(sew:getInventory():getItems():size(), 20, "nel kit")
end)

add("T-05", "portachiavi: ammesse solo le chiavi", function()
    local inv = P():getInventory()
    local ring = spawnIn(inv, "Base.KeyRing")
    local n, refused = check({ spawnIn(inv, "Base.ScrapMetal") }, ring:getInventory())
    eq(n, 0, "accodati")
    eq(refused and refused.reason, "notAllowed", "motivo")
end)

add("T-07a", "borsa a terra: dentro e fuori", function()
    local p = P()
    local bag = spawnFloor(p:getCurrentSquare(), "Base.Bag_Schoolbag")
    eq(RSK.Nested.reachable(p, bag), true, "raggiungibile")
    local b = spawnIn(p:getInventory(), "Base.Bandage")
    eq(check({ b }, bag:getInventory()), 1, "dentro")
    eq(check({ b }, p:getInventory()), 1, "fuori")
end)

add("T-07b", "borsa in un mobile vicino: dentro e fuori", function()
    local p = P()
    local sq0 = p:getCurrentSquare()
    local box
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = getCell():getGridSquare(sq0:getX() + dx, sq0:getY() + dy, sq0:getZ())
            if sq and not box then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local c = objs:get(i):getContainer()
                    if c and c:getType() ~= "floor" then box = c; break end
                end
            end
        end
    end
    if not box then error("SKIP: nessun mobile con contenitore accanto al PG") end
    local bag = spawnIn(box, "Base.Bag_Schoolbag")
    local b = spawnIn(p:getInventory(), "Base.Bandage")
    eq(check({ b }, bag:getInventory()), 1, "dentro")
    eq(check({ b }, p:getInventory()), 1, "fuori")
end)

add("T-08", "fuori portata: la finestra si chiude", function()
    local p = P()
    local sq0 = p:getCurrentSquare()
    local far = getCell():getGridSquare(sq0:getX() + 12, sq0:getY(), sq0:getZ())
    if not far then error("SKIP: quadrato lontano non caricato") end
    local near = spawnFloor(sq0, "Base.Bag_Schoolbag")
    local away = spawnFloor(far, "Base.Bag_Schoolbag")
    eq(RSK.Nested.reachable(p, away), false, "lontana raggiungibile")
    local w = RSK.Nested.open(p, near)
    eq(w ~= nil, true, "finestra vicina non aperta")
    eq(RSK.Nested.open(p, away), nil, "finestra lontana aperta")
    -- the nearby bag goes out of reach: the window closes by itself (RF-3.7)
    local wi = near:getWorldItem()
    wi:getSquare():transmitRemoveItemFromSquare(wi)
    wi:getSquare():removeWorldObject(wi)
    near:setWorldItem(nil)
    waitMs(1200)
    eq(RSK.Nested.windows[near:getID()], nil, "finestra rimasta aperta")
end)

add("T-09", "una sola finestra per contenitore; percorso nel titolo; finestra a tema", function()
    local p = P()
    local bag = spawnIn(p:getInventory(), "Base.Bag_Schoolbag")
    local kit = spawnIn(bag:getInventory(), "Base.FirstAidKit")
    local w1 = RSK.Nested.open(p, kit)
    local w2 = RSK.Nested.open(p, kit)
    eq(w1, w2, "finestra duplicata")
    eq(w1.title:find(bag:getName(), 1, true) ~= nil, true, "percorso senza la borsa")
    eq(w1.inventoryPane.inventory, kit:getInventory(), "contenitore mostrato")
    eq(#w1.backpacks, 1, "pulsanti nella colonna")
    waitMs(300) -- the reskin applies on the first frame
    eq(w1.rskStyled, true, "finestra non a tema")
end)

add("T-10", "Prendi tutto", function()
    local p = P()
    local kit = spawnIn(p:getInventory(), "Base.FirstAidKit")
    spawnMany(kit:getInventory(), "Base.Bandage", 3)
    local w = RSK.Nested.open(p, kit)
    waitMs(600)
    -- self.lootAll is the title button (vanilla FIXME): press the bottom bar control instead
    local ctl = w.controlsUI.controls
    eq(#ctl, 1, "controlli nella barra inferiore")
    ctl[1].onclick(ctl[1].target, ctl[1])
    waitQueue()
    eq(kit:getInventory():getItems():size(), 0, "rimasti nel kit")
end)

add("T-12", "chiusura col pulsante: finestra rimossa e riapribile", function()
    local p = P()
    local kit = spawnIn(p:getInventory(), "Base.FirstAidKit")
    local w = RSK.Nested.open(p, kit)
    w.closeButton.onclick(w, w.closeButton)
    eq(RSK.Nested.windows[kit:getID()], nil, "finestra ancora registrata")
    local w2 = RSK.Nested.open(p, kit)
    eq(w2 ~= w, true, "riaperta la finestra chiusa")
end)

add("T-21", "ricerca: filtro, contatore, accenti, Prendi tutto solo visibili, chiusura", function()
    local S = RSK.Search
    eq(S.Logic.fold("\195\136"), "e", "accenti in Kahlua")
    local p = P()
    local kit = spawnIn(p:getInventory(), "Base.FirstAidKit")
    local box = kit:getInventory()
    local bandages = spawnMany(box, "Base.Bandage", 3)
    spawnIn(box, "Base.AlcoholWipes")
    local w = RSK.Nested.open(p, kit)
    waitMs(600)
    eq(w.rskSearch ~= nil, true, "ricerca non agganciata")
    local s, pane = w.rskSearch, w.inventoryPane
    S.setOpen(w, true)
    eq(s.total, 4, "totale"); eq(s.shown, 4, "visibili senza testo")
    local head = RSK.Inventory.Page.headH()
    eq(pane:getY() > head, true, "riga di ricerca sopra la lista")
    S.setQuery(w, string.upper(bandages[1]:getName(p)))
    eq(#pane.itemslist, 1, "pile con filtro"); eq(s.shown, 3, "visibili con filtro"); eq(s.total, 4, "totale con filtro")
    local ctl = w.controlsUI.controls
    ctl[1].onclick(ctl[1].target, ctl[1])
    waitQueue()
    eq(box:getItems():size(), 1, "D-75: rimasti nel kit")
    S.setQuery(w, "zzzzz")
    eq(#pane.itemslist, 0, "nessun risultato")
    ctl[1].onclick(ctl[1].target, ctl[1])
    waitQueue()
    eq(box:getItems():size(), 1, "D-75: nulla di visibile, nulla spostato")
    S.setOpen(w, false)
    eq(#pane.itemslist, 1, "RF-6.5: chiusura azzera il filtro")
    eq(pane:getY(), head, "lista di nuovo sotto la barra di carico")
end)

add("T-23", "M2: apertura, schede spostate e restituite, indossa e togli, ferita, modulo spento", function()
    local Q, K = RSK.Equipment, RSK.Core
    local p = P()
    local cw = getPlayerInfoPanel(0)
    Q.destroy(0)
    cw:toggleView(xpSystemText.health)
    local w = Q.windows[0]
    eq(w ~= nil and w:isShown(), true, "M2 non aperta")
    eq(cw:getIsVisible(), false, "finestra vanilla aperta")
    eq(w.tab, "equip", "prima scheda")
    eq(cw.characterView.parent, w.scroller, "pannello Abilita' non spostato")
    -- D-90: Temperature is its own instance on the area width; the vanilla one stays in place.
    local clothing = w.tabViews.clothingIns
    eq(clothing.view ~= cw.clothingView, true, "Temperatura non e' un'istanza propria")
    eq(cw.clothingView.parent, cw.panel, "pannello Temperatura vanilla spostato")
    eq(clothing.builtW, w.scroller:getWidth(), "Temperatura non costruita sull'area")
    -- D-92: Info stays in the vanilla window, its key opens the first tab; D-94: Temperature without scrolling.
    eq(cw.charScreen.parent, cw.panel, "pannello Info spostato")
    eq(w:hasTab("info"), false, "scheda Info presente")
    eq(w:hasTab("fitness"), false, "Esercizi non e' un pannello vanilla")
    local order = {}
    for i, it in ipairs(w.tabsEl.items) do order[i] = it.id end
    eq(table.concat(order, ","), "equip,skills,fitness,protection,clothingIns", "ordine delle schede (D-95)")
    local lit = w.profile_.literature
    eq(RSK.UI.Draw.measure("button", lit.text) + 2 * RSK.Theme.px(RSK.Theme.base.space.s) <= lit:getWidth(), true, "testo di Letteratura tagliato")
    eq(w.exercises ~= nil and #w.exercises.exerciseList > 0, true, "elenco esercizi vuoto")
    eq(clothing.view.toggleAdvBtn:getBottom() <= w.scroller:getHeight(), true, "Temperatura richiede lo scorrimento")
    eq(getPlayerInventory(0).rskEquipBtn ~= nil, true, "pulsante M2 nell'inventario mancante")
    -- D-96: heart hidden, next button in its place.
    local bar = getPlayerData(0).equipped
    eq(bar.healthBtn:getIsVisible(), false, "cuore ancora visibile")
    eq(bar.craftingBtn:getY(), bar.healthBtn:getY(), "barra laterale non compattata")
    local w0, h0 = w:getWidth(), w:getHeight()
    cw:toggleView(xpSystemText.skills)
    eq(w:isShown() and w.tab == "skills", true, "cambio scheda")
    eq(cw.characterView:getIsVisible(), true, "pannello Abilita' nascosto")
    waitMs(200)
    eq(w:getWidth(), w0, "D-88: la scheda ha cambiato la larghezza della finestra")
    eq(w:getHeight(), h0, "D-88: la scheda ha cambiato l'altezza della finestra")
    eq(cw.characterView:getHeight(), w.scroller:getHeight(), "pannello con scorrimento proprio non adattato")
    cw:toggleView(xpSystemText.skills)
    eq(w:isShown(), false, "stessa scheda deve chiudere")
    cw:toggleView(xpSystemText.health)

    -- Wear and take off with vanilla actions: the slot follows, and the real game location is recognised.
    local socks = spawnIn(p:getInventory(), "Base.Socks_Ankle")
    eq(RSK.Equipment.Logic.slotFor(socks:getBodyLocation()), "feet", "location delle calze (D-83)")
    local old = p:getWornItem(socks:getBodyLocation())
    if old then ISTimedActionQueue.add(ISUnequipAction:new(p, old, 1)); waitQueue() end
    local slot = w.slots.feet
    local function inSlot()
        for _, it in ipairs(slot.items) do if it == socks then return true end end
        return false
    end
    eq(slot:accepts(socks), true, "lo slot Piedi rifiuta le calze")
    eq(w.slots.hands:accepts(socks), false, "lo slot Mani accetta le calze")
    slot:equip(socks)
    waitQueue()
    waitMs(500)
    eq(p:isEquipped(socks), true, "calze non indossate")
    eq(inSlot(), true, "calze non nello slot")
    slot:remove(socks)
    waitQueue()
    waitMs(500)
    eq(p:isEquipped(socks), false, "calze non tolte")
    eq(inSlot(), false, "slot non aggiornato")
    if old then ISTimedActionQueue.add(ISWearClothing:new(p, old, 1)); waitQueue() end

    -- Wound in the list and on the render, then restore.
    local bp = w:bodyPartByName("ForeArm_L")
    eq(bp ~= nil, true, "parte del corpo")
    local had = bp:scratched()
    bp:setScratched(true, false)
    w:refresh()
    local found
    for _, x in ipairs(w.wounds) do if x.partName == "ForeArm_L" then found = x end end
    eq(found ~= nil, true, "ferita non rilevata")
    eq(found.tok == "warn" or found.tok == "danger", true, "colore ferita")
    eq(type(found.lines[1].text), "string", "etichetta senza testo")
    w:setHoverWound(found, w.body)
    eq(w.tipOpen, true, "tooltip non aperto")
    w:setHoverWound(nil)
    eq(w.tipOpen, false, "tooltip non chiuso")
    if not had then bp:setScratched(false, true) end

    -- Weapon slots without arrows (D-87), resizing (D-88).
    eq(w.slots.primary.weapon, true, "slot arma senza frecce")
    eq(w.slots.primary:getHeight() < slot:getHeight(), true, "slot arma alto come gli altri")
    local scale = RSK.Theme.scale()
    w.bw, w.bh = 600, 900
    w:setWidth(600 * scale); w:setHeight(900 * scale)
    w:onResize()
    eq(w.lay.w, 600, "layout non ricalcolato")
    eq(w.model:getWidth() > w0 - 2 * 96 * scale, true, "render non cresciuto")
    eq(w.tabViews.clothingIns.builtW, w.scroller:getWidth(), "Temperatura non ricostruita")
    w.bw, w.bh = RSK.Equipment.Logic.WIN.W, RSK.Equipment.Logic.WIN.H
    w:setWidth(w0); w:setHeight(h0)
    w:onResize()
    eq(w.tabViews.clothingIns.builtW, w.scroller:getWidth(), "Temperatura non ricostruita al ritorno")

    -- Hair and beard (D-85): data read from the vanilla panel, scrolling tabs (D-86).
    eq(type(w.hairText), "string", "stile capelli")
    cw:toggleView(xpSystemText.clothingIns)
    eq(w.tabsEl.selected, "clothingIns", "scheda attiva")
    waitMs(300) -- the panel asks for its size on the first draw: the window adapts and the tabs scroll
    local rects, last = w.tabsEl:tabRects(), nil
    for _, r in ipairs(rects) do if r.id == "clothingIns" then last = r end end
    eq(last.x + last.w - w.tabsEl.scroll <= w.tabsEl.width, true, "scheda attiva fuori dalla finestra")
    cw:toggleView(xpSystemText.health)

    -- Module off: panels handed back and vanilla window; then M2 again.
    T.reenable = Q.ID -- if the test fails from here on, cleanup re-enables the module (the setting is saved to file)
    K.setEnabled(Q.ID, false)
    eq(Q.windows[0], nil, "finestra M2 rimasta")
    eq(cw.characterView.parent, cw.panel, "pannello non restituito")
    eq(getPlayerInventory(0).rskEquipBtn, nil, "pulsante M2 rimasto a modulo spento")
    waitMs(200)
    eq(bar.healthBtn:getIsVisible(), true, "cuore non tornato a modulo spento")
    eq(bar.craftingBtn:getY() > bar.healthBtn:getY(), true, "barra laterale non ripristinata")
    cw:toggleView(xpSystemText.health)
    eq(cw:getIsVisible(), true, "finestra vanilla non aperta")
    cw:close()
    K.setEnabled(Q.ID, true)
    T.reenable = nil
    cw:toggleView(xpSystemText.health)
    eq(Q.windows[0] ~= nil and Q.windows[0]:isShown(), true, "M2 non riaperta")
    Q.destroy(0)
end)

-- ------------------------------------------------------------------ run
function T.finish()
    cleanup()
    local p = P()
    if p and T.oldInstant ~= nil then p:setTimedActionInstantCheat(T.oldInstant) end
    local r = T.res
    log(string.format("RIEPILOGO: %d ok, %d falliti, %d saltati, %d controlli di contratto", r.pass, r.fail, r.skip, T.contracts))
    T.running, T.co, T.cur = false, nil, nil
end

function T.next()
    cleanup()
    T.idx = T.idx + 1
    local t = T.list[T.idx]
    if not t then return T.finish() end
    T.cur = t
    T.co = coroutine.create(t.fn)
end

function T.run()
    if T.running then log("gia' in esecuzione"); return end
    local p = P()
    if not p then return end
    T.running, T.idx = true, 0
    T.res, T.contracts = { pass = 0, fail = 0, skip = 0 }, 0
    T.oldInstant = p:isTimedActionInstantCheat()
    p:setTimedActionInstantCheat(true)
    ISTimedActionQueue.clear(p)
    log("inizio: " .. #T.list .. " test")
    T.next()
end

local function onTick()
    if not T.running or not T.co then return end
    local t = T.cur
    -- After a "continue" in the Lua debugger the coroutine stays in "normal" state: resuming it would raise an error
    -- (and a debug window) on every tick. The failure is recorded and the run stops.
    local status = coroutine.status(T.co)
    if status ~= "suspended" then
        T.res.fail = T.res.fail + 1
        log("FAIL " .. t.id .. " " .. t.name .. ": esecuzione interrotta (coroutine in stato " .. status .. "); test successivi non eseguiti")
        T.finish()
        return
    end
    local ok, err = coroutine.resume(T.co)
    if not ok then
        local msg = tostring(err)
        if msg:find("SKIP:", 1, true) then
            T.res.skip = T.res.skip + 1
            log("SKIP " .. t.id .. " " .. t.name .. ": " .. msg)
        else
            T.res.fail = T.res.fail + 1
            log("FAIL " .. t.id .. " " .. t.name .. ": " .. msg)
        end
        T.next()
    elseif coroutine.status(T.co) == "dead" then
        T.res.pass = T.res.pass + 1
        log("PASS " .. t.id .. " " .. t.name)
        T.next()
    end
end

local function onFillWorldMenu(playerNum, context, worldobjects, test)
    if test then return end
    context:addOption("RSK: esegui test", nil, T.run)
    if RSK.Gallery and RSK.Gallery.open then context:addOption("RSK: galleria widget", nil, RSK.Gallery.open) end
end

Events.OnTick.Add(onTick)
Events.OnFillWorldObjectContextMenu.Add(onFillWorldMenu)
