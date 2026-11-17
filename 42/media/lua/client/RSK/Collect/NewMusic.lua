-- RSK.Collect.NewMusic - compatibility with the NewMusic mod and its album packs (D-142, D-143).
-- One collectible = one album: any cassette side, vinyl side, CD or full case of the album
-- finds it. Empty cases do not count. NewMusic keeps no "listened" data: only found / not found.
-- Album index: NewMusic album definitions are global tables { module, id, media = { cassette =
-- { items = { a, b, containerEmpty, containerFull } }, vinyl = ..., cd = { items = { full, ... } } } }.
-- Media NewMusic plays but that are not in the index (albums declared as locals, e.g. the
-- bundled OST) count per side pair, through NMMediaContract.resolveMediaCanonical.
-- Vanilla items ("Base.") are left to the vanilla rules (NewMusic also plays vanilla CDs).
require "RSK/Collect/Logic"

RSK = RSK or {}
RSK.Collect = RSK.Collect or {}
RSK.Collect.NewMusic = RSK.Collect.NewMusic or {}
local NM = RSK.Collect.NewMusic
local L = RSK.Collect.Logic
NM.ID = "NewMusic"

-- fullType -> "album:<module>:<id>", from every global table that looks like an album definition.
function NM.buildIndex(env)
    local idx = {}
    for _, v in pairs(env or {}) do
        if type(v) == "table" and type(rawget(v, "media")) == "table" and type(rawget(v, "id")) == "string"
            and type(rawget(v, "module")) == "string" then
            local album = "album:" .. v.module .. ":" .. v.id
            for _, md in pairs(v.media) do
                local items = type(md) == "table" and md.items or nil
                if type(items) == "table" then
                    for slot, it in pairs(items) do
                        if slot ~= "containerEmpty" and type(it) == "string" and it ~= "" then
                            idx[v.module .. "." .. it] = album
                        end
                    end
                end
            end
        end
    end
    return idx
end

-- Key for a full type, or nil. api = { tracks = fn(fullType) -> resolved table or nil,
-- canonical = fn(fullType) -> canonical side-A type }.
function NM.key(index, fullType, api)
    if type(fullType) ~= "string" or fullType == "" or fullType:sub(1, 5) == "Base." then return nil end
    local album = index and index[fullType]
    if album then return album end
    local tracks = api and api.tracks and api.tracks(fullType)
    if type(tracks) == "table" and type(tracks.tracks) == "table" and #tracks.tracks > 0 then
        local canon = api.canonical and api.canonical(fullType) or fullType
        return "media:" .. tostring(canon or fullType)
    end
    return nil
end

-- Engine side: the index is built on first use, when every pack has declared its albums.
local engineApi = {
    tracks = function(ft)
        if not (NMTrackCatalog and NMTrackCatalog.resolveTracks) then return nil end
        local ok, r = pcall(NMTrackCatalog.resolveTracks, ft)
        return ok and r or nil
    end,
    canonical = function(ft)
        if NMMediaContract and NMMediaContract.resolveMediaCanonical then return NMMediaContract.resolveMediaCanonical(ft) end
        return ft
    end,
}
function NM.match(_, fullType)
    if not NM.index then NM.index = NM.buildIndex(_G) end
    return NM.key(NM.index, fullType, engineApi)
end

-- Registered only when NewMusic is loaded (its shared files run before this client file).
if NMMediaContract ~= nil then
    L.register({ id = NM.ID, match = NM.match })
end
