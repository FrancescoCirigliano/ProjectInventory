"""Runs the RSK Lua 5.1 unit tests (D-39, D-46). Usage: python tests/run_unit.py
Requires: pip install lupa. Exit code 1 if a test fails."""
import pathlib
import sys

from lupa import lua51

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA_CLIENT = ROOT / "42" / "media" / "lua" / "client"
UNIT = ROOT / "tests" / "unit"

MODULES = [
    "RSK/Core/TransferRules.lua",
    "RSK/Core/EventBus.lua",
    "RSK/Core/Config.lua",
    "RSK/Core/Bootstrap.lua",
    "RSK/Theme/Presets.lua",
    "RSK/Theme/FontSizes.lua",
    "RSK/Theme/Theme.lua",
    "RSK/UI/Logic.lua",
    "RSK/Inventory/Logic.lua",
    "RSK/Inventory/TipLogic.lua",
    "RSK/Nested/Logic.lua",
    "RSK/Search/Logic.lua",
    "RSK/Equipment/Logic.lua",
    "RSK/Settings/Logic.lua",
    "RSK/Collect/Logic.lua",
    "RSK/Collect/NewMusic.lua",
]
TESTS = sorted(UNIT.glob("test_*.lua"))


def main() -> int:
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(f'package.path = "{UNIT.as_posix()}/?.lua;" .. package.path')
    for mod in MODULES:
        lua.execute((LUA_CLIENT / mod).read_text(encoding="utf-8"))
        lua.execute(f'package.loaded["{mod[:-4]}"] = true')
    failed = 0
    for test in TESTS:
        res = lua.execute(test.read_text(encoding="utf-8"))
        print(f"== {test.name}")
        for i in range(1, len(res["lines"]) + 1):
            print("  " + res["lines"][i])
        print(f"  {res['pass']} ok, {res['fail']} falliti")
        failed += res["fail"]
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
