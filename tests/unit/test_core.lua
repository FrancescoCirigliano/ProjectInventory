-- Core unit tests (D-46): RSK.Bus, RSK.Config, RSK.Core. Scenarios T-12...T-14 (see docs/Test.md).
local B, C, K = RSK.Bus, RSK.Config, RSK.Core

local results = { pass = 0, fail = 0, lines = {} }
local function test(id, name, fn)
    local ok, err = pcall(fn)
    if ok then
        results.pass = results.pass + 1
        results.lines[#results.lines + 1] = "PASS " .. id .. " " .. name
    else
        results.fail = results.fail + 1
        results.lines[#results.lines + 1] = "FAIL " .. id .. " " .. name .. ": " .. tostring(err)
    end
end
local function eq(a, b, msg)
    if a ~= b then error((msg or "valore") .. ": atteso " .. tostring(b) .. ", ottenuto " .. tostring(a), 2) end
end

-- Clean environment: empty bus, in-memory config, no modules.
local file
local function reset()
    B.listeners, B.pending, B.pendingIndex = {}, {}, {}
    C.schema, C.order, C.values, C.extra, C.loaded = {}, {}, {}, {}, false
    file = nil
    C.io = {
        read = function() return file end,
        write = function(_, lines) file = lines; return true end,
    }
    K.modules, K.order, K.phase = {}, {}, "load"
    K.log = function() end
end

-- T-12 Event bus
test("T-12a", "emit chiama gli ascoltatori con gli argomenti", function()
    reset()
    local got
    B.on("X", function(a, b) got = a .. b end)
    eq(B.emit("X", "a", "b"), 1, "eseguiti"); eq(got, "ab")
end)
test("T-12b", "post raggruppa per (evento, chiave); vince l'ultimo", function()
    reset()
    local calls = {}
    B.on("E", function(p, v) calls[#calls + 1] = p .. ":" .. v end)
    B.post("E", 0, 0, "a"); B.post("E", 0, 0, "b"); B.post("E", 1, 1, "c")
    eq(#calls, 0, "prima del flush")
    eq(B.flush(), 2, "invii"); eq(#calls, 2); eq(calls[1], "0:b"); eq(calls[2], "1:c")
    eq(B.flush(), 0, "coda vuota")
end)
test("T-12c", "post senza ascoltatori non accoda", function()
    reset()
    B.post("Nessuno", 0); eq(#B.pending, 0)
end)
test("T-12d", "post conserva argomenti nil", function()
    reset()
    local n
    B.on("E", function(...) n = select("#", ...) end)
    B.post("E", "k", nil, 2); B.flush(); eq(n, 2)
end)
test("T-12e", "un ascoltatore in errore non blocca gli altri; onError riceve il proprietario", function()
    reset()
    local owner, ok2
    local prev = B.onError
    B.onError = function(o) owner = o end
    B.on("E", function() error("boom") end, "ModA")
    B.on("E", function() ok2 = true end, "ModB")
    eq(B.emit("E"), 1); eq(owner, "ModA"); eq(ok2, true)
    B.onError = prev
end)
test("T-12f", "offOwner rimuove solo gli ascoltatori del modulo, anche durante un emit", function()
    reset()
    local hit = 0
    B.on("E", function() B.offOwner("M") end, "Altro")
    B.on("E", function() hit = hit + 1 end, "M")
    B.emit("E"); eq(hit, 0, "rimosso durante l'emit"); eq(#B.listeners.E, 1)
end)

-- T-13 Config
test("T-13a", "parse: commenti, spazi, '=' nel valore", function()
    local raw = C.parse({ "# c", "", "  a = 1 ", "b=x=y", "senza uguale" })
    eq(raw.a, "1"); eq(raw.b, "x=y"); eq(raw["senza uguale"], nil)
end)
test("T-13b", "valori non validi -> predefinito", function()
    reset()
    C.define("b", "bool", true); C.define("n", "number", 1, { min = 0.5, max = 2 })
    C.define("e", "enum", "ruggine", { values = { "ruggine", "militare", "notte" } })
    C.define("c", "color", "#aabbcc")
    file = { "b = forse", "n = 7", "e = verde", "c = #12345" }
    C.load()
    eq(C.get("b"), true); eq(C.get("n"), 1); eq(C.get("e"), "ruggine"); eq(C.get("c"), "#aabbcc")
end)
test("T-13c", "valori validi letti e convertiti", function()
    reset()
    C.define("b", "bool", true); C.define("n", "number", 1, { min = 0.5, max = 2 })
    C.define("c", "color", "#aabbcc")
    file = { "b = false", "n = 1.5", "c = #FF00aa" }
    C.load()
    eq(C.get("b"), false); eq(C.get("n"), 1.5); eq(C.get("c"), "#ff00aa")
end)
test("T-13d", "file assente o lettura in errore -> predefiniti", function()
    reset()
    C.define("b", "bool", true)
    C.io.read = function() error("io") end
    C.load(); eq(C.get("b"), true); eq(C.loaded, true)
end)
test("T-13e", "set: valida, salva, notifica solo se cambia", function()
    reset()
    C.define("n", "number", 1, { min = 0, max = 10 })
    local ev = 0
    B.on("ConfigChanged", function() ev = ev + 1 end)
    eq(C.set("n", 99), false, "fuori intervallo"); eq(file, nil, "non salvato")
    eq(C.set("n", 3), true); eq(ev, 1); eq(C.get("n"), 3)
    eq(C.set("n", 3), true); eq(ev, 1, "nessun cambio")
    eq(C.set("ignota", 1), false)
end)
test("T-13f", "andata e ritorno; chiavi sconosciute conservate", function()
    reset()
    C.define("a", "string", "x"); C.define("n", "number", 2)
    file = { "version = 1", "futura.chiave = 42", "a = ciao mondo" }
    C.load(); C.set("n", 5)
    local saved = file
    reset()
    C.define("a", "string", "x"); C.define("n", "number", 2)
    file = saved; C.load()
    eq(C.get("a"), "ciao mondo"); eq(C.get("n"), 5); eq(C.extra["futura.chiave"], "42"); eq(C.fileVersion, 1)
end)
test("T-13g", "reset riporta ai predefiniti", function()
    reset()
    C.define("n", "number", 2)
    C.set("n", 4); C.reset(); eq(C.get("n"), 2)
end)

-- T-14 Core (modules)
local function mod(id, extra)
    local m = { id = id, when = "boot", starts = 0, stops = 0 }
    m.start = function(self) self.starts = self.starts + 1 end
    m.stop = function(self) self.stops = self.stops + 1 end
    for k, v in pairs(extra or {}) do m[k] = v end
    return m
end
test("T-14a", "avvio per fase: boot e game", function()
    reset()
    local a = K.register(mod("A")); local g = K.register(mod("G", { when = "game" }))
    eq(a.state, "off"); K.boot(); eq(a.state, "on"); eq(g.state, "off")
    K.gameStart(); eq(g.state, "on"); eq(a.starts, 1, "avviato una volta")
end)
test("T-14b", "registrato dopo l'avvio parte subito", function()
    reset(); K.boot()
    local a = K.register(mod("A")); eq(a.state, "on")
end)
test("T-14c", "disattivato in config non parte", function()
    reset()
    local a = K.register(mod("A"))
    file = { "module.A = false" }
    K.boot(); eq(a.state, "disabled"); eq(a.starts, 0)
end)
test("T-14d", "errore in start -> failed, ascoltatori rimossi", function()
    reset()
    local m = K.register(mod("A", { start = function(self) B.on("E", function() end, "A"); error("x") end }))
    K.boot(); eq(m.state, "failed"); eq(B.has("E"), false); eq(m.stops, 1, "stop chiamato per ripulire")
end)
test("T-14e", "errore in un ascoltatore -> modulo spento e stop chiamato", function()
    reset()
    local m = K.register(mod("A", { start = function() B.on("E", function() error("y") end, "A") end }))
    K.boot(); B.emit("E")
    eq(m.state, "failed"); eq(m.stops, 1); eq(B.has("E"), false)
end)
test("T-14f", "guard: errore spegne il modulo, poi ritorna false", function()
    reset()
    local m = K.register(mod("A")); K.boot()
    local f = K.guard("A", function(x) if x then error("z") end return 1, nil, 3 end)
    local a, b, c = f(false); eq(a, 1); eq(b, nil); eq(c, 3)
    eq(f(true), false); eq(m.state, "failed"); eq(f(false), false, "modulo spento")
end)
test("T-14g", "dipendenze: bloccato senza requisito; spento se il requisito cade", function()
    reset()
    local a = K.register(mod("A")); local d = K.register(mod("D", { requires = { "A" } }))
    file = { "module.A = false" }
    K.boot(); eq(d.state, "blocked")
    K.setEnabled("A", true); K.setEnabled("D", true); eq(a.state, "on"); eq(d.state, "on")
    K.fail("A", "boom"); eq(a.state, "failed"); eq(d.state, "blocked"); eq(d.stops, 1)
end)
test("T-14h", "setEnabled a caldo e riattivazione dopo errore", function()
    reset()
    local m = K.register(mod("A")); K.boot()
    K.setEnabled("A", false); eq(m.state, "disabled"); eq(C.get("module.A"), false)
    K.fail("A", "x"); K.setEnabled("A", true); eq(m.state, "on"); eq(m.starts, 2)
end)
test("T-14i", "errore nello stop non blocca lo spegnimento", function()
    reset()
    local m = K.register(mod("A", { stop = function() error("s") end })); K.boot()
    K.setEnabled("A", false); eq(m.state, "disabled")
end)
test("T-14j", "riaccendere un requisito riavvia i dipendenti bloccati (D-125)", function()
    reset()
    local a = K.register(mod("A")); local d = K.register(mod("D", { requires = { "A" } })); K.boot()
    K.setEnabled("A", false); eq(d.state, "blocked"); eq(C.get("module.D"), true, "config del dipendente intatta")
    K.setEnabled("A", true); eq(a.state, "on"); eq(d.state, "on"); eq(d.starts, 2)
end)
test("T-13h", "reset di un elenco di chiavi: le altre restano", function()
    reset()
    C.define("x", "number", 1); C.define("y", "number", 2)
    C.set("x", 5); C.set("y", 6); C.reset({ "x" }); eq(C.get("x"), 1); eq(C.get("y"), 6)
end)

return results
