"""Build RecipeAtlasData.lua from the public CMaNGOS WotLK world DB and 3.3.5a DBC files.

Build-time only: the WoW addon itself is pure Lua and never runs this script.

Inputs (default folder: AddOns/.recipeatlas-work, override with RECIPEATLAS_WORK):
  wotlkmangos.sqlite      - from wotlk-sqlite-db.zip, https://github.com/cmangos/wotlk-db/releases
  WorldMapArea.dbc, WorldMapOverlay.dbc, DungeonMap.dbc, Map.dbc, AreaTable.dbc, Faction.dbc,
  FactionTemplate.dbc, SkillLineAbility.dbc, Spell.dbc   - 3.3.5a (12340) client DBC files
"""

import os
import sqlite3
import struct
import sys
from collections import defaultdict, Counter

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ADDON_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
WORK_DIR = os.environ.get("RECIPEATLAS_WORK") or os.path.abspath(os.path.join(ADDON_DIR, "..", ".recipeatlas-work"))
DB = os.path.join(WORK_DIR, "wotlkmangos.sqlite")
OUT = os.path.join(ADDON_DIR, "RecipeAtlasData.lua")

PROFESSIONS = {171: "ALCHEMY", 164: "BLACKSMITHING", 185: "COOKING", 333: "ENCHANTING",
               202: "ENGINEERING", 186: "MINING", 129: "FIRST_AID", 773: "INSCRIPTION",
               755: "JEWELCRAFTING", 165: "LEATHERWORKING", 197: "TAILORING"}
# Spell effects of entries that appear in the trade skill window.
RECIPE_EFFECTS = {24, 53, 54, 59, 76, 92, 157}
WORLD_DROP_NPCS = 25          # more mobs than this = "world drop", no per-mob pins
ALLIANCE_RACES, HORDE_RACES = 1101, 690
HOLIDAYS = {141: "WINTER_VEIL", 181: "NOBLEGARDEN", 201: "CHILDRENS_WEEK", 321: "HARVEST_FESTIVAL",
            324: "HALLOWS_END", 327: "LUNAR_FESTIVAL", 341: "MIDSUMMER", 372: "BREWFEST",
            374: "DARKMOON_ELWYNN", 375: "DARKMOON_MULGORE", 376: "DARKMOON_TEROKKAR",
            398: "PIRATES_DAY", 404: "PILGRIMS_BOUNTY", 409: "DAY_OF_THE_DEAD",
            423: "LOVE_IS_IN_THE_AIR", 301: "FISHING_EXTRAVAGANZA", 424: "KALUAK_DERBY"}
QUEST_SORT_HOLIDAYS = {-41: "DAY_OF_THE_DEAD", -364: "DARKMOON", -366: "LUNAR_FESTIVAL", -369: "MIDSUMMER",
                       -370: "BREWFEST", -374: "NOBLEGARDEN", -375: "PILGRIMS_BOUNTY", -376: "LOVE_IS_IN_THE_AIR"}
# Event recipes whose vendors are missing from the CMaNGOS vendor tables.
HOLIDAY_RECIPE_ITEMS = {i: "PILGRIMS_BOUNTY" for i in (44858, 44859, 44860, 44861, 44862, 46803, 46804, 46805, 46806, 46807)}
ALL_CLASSES = 1535                     # warrior..druid bits of 3.3.5a
DALARAN_FLOORS = {1: (222.495, 1052.51, 5513.33, 6066.67), 2: (352.646, 915.87, 5599.85, 5975.34)}


# ---------------------------------------------------------------- DBC helpers
def read_dbc(name):
    path = os.path.join(WORK_DIR, name)
    data = open(path, "rb").read()
    magic, count, fields, size, _ = struct.unpack_from("<4sIIII", data)
    if magic != b"WDBC":
        raise ValueError(name + " is not a WDBC file")
    strings = data[20 + count * size:]

    def string_at(offset):
        end = strings.find(b"\x00", offset)
        return strings[offset:end].decode("utf-8", "replace")
    rows = [data[20 + i * size:20 + (i + 1) * size] for i in range(count)]
    return rows, fields, string_at


def load_world_map_areas():
    rows, _, s = read_dbc("WorldMapArea.dbc")
    areas = []
    for r in rows:
        map_id, area_id = struct.unpack_from("<II", r, 4)
        name_offset, = struct.unpack_from("<I", r, 12)
        left, right, top, bottom = struct.unpack_from("<ffff", r, 16)
        if area_id and left != right and top != bottom:
            areas.append({"id": struct.unpack_from("<I", r, 0)[0], "map": map_id, "name": s(name_offset), "L": left, "R": right, "T": top, "B": bottom,
                          "area": abs((left - right) * (top - bottom))})
    load_overlays(areas)
    return areas


def load_overlays(areas):
    """Explored-area rectangles of each zone map (normalized 0..1). They tell which zone a point
    really belongs to where the rectangular zone bounds overlap (e.g. Darkshore vs Felwood)."""
    path = os.path.join(WORK_DIR, "WorldMapOverlay.dbc")
    by_id = {a["id"]: a for a in areas}
    for a in areas:
        a["overlays"] = []
    if not os.path.exists(path):
        print("warning: WorldMapOverlay.dbc missing, zone borders use bounding boxes only")
        return
    rows, fields, _ = read_dbc("WorldMapOverlay.dbc")
    for r in rows:
        v = struct.unpack("<%dI" % fields, r)
        area = by_id.get(v[1])
        w, h, ox, oy = v[9], v[10], v[11], v[12]
        if area and w and h:
            area["overlays"].append((ox / 1002.0, oy / 668.0, (ox + w) / 1002.0, (oy + h) / 668.0))


def load_maps():
    rows, fields, s = read_dbc("Map.dbc")
    out = {}
    for r in rows:
        v = struct.unpack("<%dI" % fields, r)
        out[v[0]] = (v[2], s(v[5]))      # instance type, English name
    return out


def load_area_names():
    rows, fields, s = read_dbc("AreaTable.dbc")
    return {struct.unpack_from("<I", r, 0)[0]: s(struct.unpack_from("<I", r, 44)[0]) for r in rows}


def load_faction_names():
    rows, fields, s = read_dbc("Faction.dbc")
    return {struct.unpack_from("<I", r, 0)[0]: s(struct.unpack_from("<I", r, 23 * 4)[0]) for r in rows}


def load_faction_templates():
    rows, fields, _ = read_dbc("FactionTemplate.dbc")
    out = {}
    for r in rows:
        v = struct.unpack("<%dI" % fields, r)
        side = None
        for mask in (v[4], v[3]):          # FriendGroup, then FactionGroup
            if mask & 2 and not mask & 4:
                side = "A"
                break
            if mask & 4 and not mask & 2:
                side = "H"
                break
        out[v[0]] = side
    return out


def load_skill_line_abilities():
    """spell -> profession, spell -> allowed class mask (0 = every class)."""
    rows, fields, _ = read_dbc("SkillLineAbility.dbc")
    out, classes = {}, {}
    for r in rows:
        v = struct.unpack("<%dI" % fields, r)
        if v[1] in PROFESSIONS:
            out.setdefault(v[2], v[1])
            mask = v[4] & ~v[6] & ALL_CLASSES if v[4] else (ALL_CLASSES & ~v[6])
            classes[v[2]] = classes.get(v[2], 0) | mask
    return out, classes


def load_spell_effects():
    rows, fields, s = read_dbc("Spell.dbc")
    out = {}
    for r in rows:
        sid, = struct.unpack_from("<I", r, 0)
        effects = struct.unpack_from("<3I", r, 71 * 4)
        triggers = struct.unpack_from("<3I", r, 116 * 4)
        name = s(struct.unpack_from("<I", r, 136 * 4)[0])
        items = struct.unpack_from("<3I", r, 107 * 4)
        created = next((item for effect, item in zip(effects, items) if effect in (24, 157) and item), 0)
        out[sid] = (effects, name, triggers, created)
    return out


def locate(map_id, x, y, z, areas, maps):
    """World x/y -> (mapFile, nx, ny, floor) or (None, instance name)."""
    if map_id == 571:
        for floor in (2, 1):
            minY, maxY, minX, maxX = DALARAN_FLOORS[floor]
            if minX <= x <= maxX and minY <= y <= maxY:
                # Coordinates are always stored in the city-floor frame (the one Astrolabe
                # and the minimap use); f=2 marks the Underbelly, which the addon converts.
                minY, maxY, minX, maxX = DALARAN_FLOORS[1]
                if floor == 2 and 550 < z < 636:
                    return ("Dalaran", (maxY - y) / (maxY - minY), (maxX - x) / (maxX - minX), 2)
                if floor == 1 and z >= 636:
                    return ("Dalaran", (maxY - y) / (maxY - minY), (maxX - x) / (maxX - minX), 1)
    candidates, nearest = [], None
    for a in areas:
        if a["map"] != map_id:
            continue
        nx = (a["L"] - y) / (a["L"] - a["R"])
        ny = (a["T"] - x) / (a["T"] - a["B"])
        dx, dy = max(0.0, -nx, nx - 1.0), max(0.0, -ny, ny - 1.0)
        d = dx * dx + dy * dy
        if d == 0:
            candidates.append((a["area"], a, nx, ny))
        elif nearest is None or d < nearest[0]:
            nearest = (d, a, nx, ny)
    if len(candidates) > 1:
        # overlapping zone rectangles: prefer the zone whose explored areas contain/are nearest the point
        def overlay_distance(c):
            _, a, nx, ny = c
            if not a["overlays"]:
                return (0.0, c[0])      # cities and small maps have no overlays: trust the bounds
            wx, wy = abs(a["L"] - a["R"]), abs(a["T"] - a["B"])
            best = None
            for x1, y1, x2, y2 in a["overlays"]:
                dx = max(0.0, x1 - nx, nx - x2) * wx
                dy = max(0.0, y1 - ny, ny - y2) * wy
                cx, cy = ((x1 + x2) / 2 - nx) * wx, ((y1 + y2) / 2 - ny) * wy
                d = dx * dx + dy * dy
                if best is None or d < best:
                    best = d
            return (best, c[0])
        _, a, nx, ny = min(candidates, key=overlay_distance)
    elif candidates:
        _, a, nx, ny = candidates[0]
    elif nearest and nearest[0] <= 0.0036:
        _, a, nx, ny = nearest
    else:
        info = maps.get(map_id)
        return (None, info[1] if info else None)
    return (a["name"], max(0.0, min(1.0, nx)), max(0.0, min(1.0, ny)), 0)


# ---------------------------------------------------------------- loot helpers
class Loot:
    def __init__(self, db):
        self.db = db
        self.tables = {}
        self.memo = {}

    def rows(self, table, entry):
        if table not in self.tables:
            idx = defaultdict(list)
            for row in self.db.execute('SELECT entry,item,ChanceOrQuestChance,groupid,mincountOrRef,maxcount FROM "%s"' % table):
                idx[row[0]].append(row[1:])
            self.tables[table] = idx
        return self.tables[table].get(entry, ())

    def resolve(self, table, entry, depth=0):
        """item -> chance (0..1) for one loot entry, following references."""
        key = (table, entry)
        if key in self.memo:
            return self.memo[key]
        result = {}
        if depth > 6:
            return result
        groups = defaultdict(list)
        for item, chance, group, mincount, maxcount in self.rows(table, entry):
            groups[group].append((item, abs(chance or 0), mincount, maxcount))

        def add(item, p):
            result[item] = 1 - (1 - result.get(item, 0)) * (1 - min(1.0, p))

        for group, entries in groups.items():
            if group == 0:
                shares = {id(e): e[1] / 100.0 for e in entries}
            else:
                explicit = sum(e[1] for e in entries if e[1] > 0)
                zero = [e for e in entries if e[1] == 0]
                rest = max(0.0, 100.0 - explicit) / len(zero) if zero else 0
                shares = {id(e): (e[1] if e[1] > 0 else rest) / 100.0 for e in entries}
            for e in entries:
                item, _, mincount, maxcount = e
                p = shares[id(e)]
                if mincount is not None and mincount < 0:
                    rolls = max(1, maxcount or 1)
                    for sub_item, sub_p in self.resolve("reference_loot_template", -mincount, depth + 1).items():
                        add(sub_item, 1 - (1 - p * sub_p) ** rolls)
                elif item:
                    add(item, p)
        self.memo[key] = result
        return result


def lua_string(text):
    text = (text or "").replace("\\", "\\\\").replace('"', '\\"').replace("\r", " ").replace("\n", " ")
    return '"' + text + '"'


def fmt_chance(p):
    v = round(p * 100, 2 if p < 0.01 else 1)
    return ("%g" % v)


# ---------------------------------------------------------------- main
def main():
    if not os.path.exists(DB):
        sys.exit("Missing %s (see the header of this script)" % DB)
    db = sqlite3.connect(DB)
    q = db.execute
    areas, maps = load_world_map_areas(), load_maps()
    area_names, faction_names = load_area_names(), load_faction_names()
    templates = load_faction_templates()
    sla, sla_classes = load_skill_line_abilities()
    spells = load_spell_effects()

    def is_trade_recipe(spell):
        info = spells.get(spell)
        return bool(info) and any(e in RECIPE_EFFECTS for e in info[0])

    recipes = {}

    def taught_spell(spell):
        info = spells.get(spell)
        if info and not any(e in RECIPE_EFFECTS for e in info[0]):
            for effect, trigger in zip(info[0], info[2]):
                if effect == 36 and trigger and is_trade_recipe(trigger):
                    return trigger
        return spell

    def recipe_for(spell, profession):
        spell = taught_spell(spell)
        prof = sla.get(spell) or profession
        if prof not in PROFESSIONS or not is_trade_recipe(spell):
            return None
        r = recipes.get(spell)
        if not r:
            r = recipes[spell] = {"p": prof, "i": 0, "r": 0, "rf": 0, "rr": 0, "src": {}, "price": 0, "side": None}
        return r

    def src(r, kind):
        return r["src"].setdefault(kind, {"n": {}, "q": set(), "o": {}, "i": {}, "d": set(), "f": {}})

    creature_tpl = {}
    for row in q("SELECT Entry,Name,Faction,MinLevel,MaxLevel,LootId,TrainerTemplateId,VendorTemplateId,"
                 "DifficultyEntry1,DifficultyEntry2,DifficultyEntry3 FROM creature_template"):
        creature_tpl[row[0]] = row
    heroic_parent = {}
    for row in creature_tpl.values():
        for diff in row[8:11]:
            if diff:
                heroic_parent[diff] = row[0]

    # ---- trainers (direct rows and shared templates)
    trainers_by_template = defaultdict(list)
    for row in creature_tpl.values():
        if row[6]:
            trainers_by_template[row[6]].append(row[0])
    trainer_rows = [(npc, spell, skill, value) for npc, spell, skill, value in
                    q("SELECT entry,spell,reqskill,reqskillvalue FROM npc_trainer")]
    for tpl, spell, skill, value in q("SELECT entry,spell,reqskill,reqskillvalue FROM npc_trainer_template"):
        for npc in trainers_by_template.get(tpl, ()):
            trainer_rows.append((npc, spell, skill, value))
    for npc, spell, skill, value in trainer_rows:
        if npc not in creature_tpl:
            continue
        r = recipe_for(spell, skill)
        if r:
            r["r"] = max(r["r"], value or 0)
            src(r, "t")["n"][npc] = 1

    # ---- recipe items
    item_to_spell = {}
    item_names = {}
    for row in q("SELECT entry,name,RequiredSkill,RequiredSkillRank,RequiredReputationFaction,RequiredReputationRank,"
                 "AllowableRace,BuyPrice,AllowableClass,spellid_1,spelltrigger_1,spellid_2,spelltrigger_2,spellid_3,spelltrigger_3 "
                 "FROM item_template WHERE class=9"):
        entry, name, skill, rank, rf, rr, races, price, classes = row[:9]
        for k in range(9, 15, 2):
            spell, trigger = row[k], row[k + 1]
            if spell and trigger == 6:
                r = recipe_for(spell, skill)
                if not r:
                    continue
                spell = taught_spell(spell)
                r.setdefault("items", set()).add(entry)
                if not r["i"] or r["i"] > entry:
                    r["i"] = entry
                    r["price"] = price or 0
                r["r"] = max(r["r"], rank or 0)
                if rf:
                    r["rf"], r["rr"] = rf, rr
                races = races or 0
                side = None
                if races > 0 and races & ALLIANCE_RACES and not races & HORDE_RACES:
                    side = "A"
                elif races > 0 and races & HORDE_RACES and not races & ALLIANCE_RACES:
                    side = "H"
                r.setdefault("item_sides", set()).add(side)
                classes = classes if classes and classes > 0 else ALL_CLASSES
                r["item_classes"] = r.get("item_classes", 0) | (classes & ALL_CLASSES)
                if entry in HOLIDAY_RECIPE_ITEMS:
                    r["manual_holiday"] = HOLIDAY_RECIPE_ITEMS[entry]
                item_to_spell.setdefault(entry, set()).add(spell)
                item_names[entry] = name

    # ---- discoveries
    for spell, req_spell, req_value, chance in q("SELECT spellId,reqSpell,reqSkillValue,chance FROM skill_discovery_template"):
        r = recipe_for(spell, 0)
        if r:
            spell = taught_spell(spell)
            r["r"] = max(r["r"], req_value or 0)
            src(r, "d")["d"].add(req_spell if req_spell and req_spell > 0 else 0)

    # ---- vendors
    vendors_by_template = defaultdict(list)
    for row in creature_tpl.values():
        if row[7]:
            vendors_by_template[row[7]].append(row[0])
    vendor_rows = list(q("SELECT entry,item,maxcount FROM npc_vendor"))
    for tpl, item, maxcount in q("SELECT entry,item,maxcount FROM npc_vendor_template"):
        for npc in vendors_by_template.get(tpl, ()):
            vendor_rows.append((npc, item, maxcount))
    for npc, item, maxcount in vendor_rows:
        for spell in item_to_spell.get(item, ()):
            if npc in creature_tpl:
                s = src(recipes[spell], "v")
                s["n"][npc] = 2 if maxcount else 1     # 2 = limited supply

    # ---- creature / object / item / fishing loot
    loot = Loot(db)
    npcs_by_loot = defaultdict(list)
    for row in creature_tpl.values():
        if row[5]:
            npcs_by_loot[row[5]].append(row[0])
    for (loot_id,) in q("SELECT DISTINCT entry FROM creature_loot_template"):
        if loot_id not in npcs_by_loot:
            continue
        for item, p in loot.resolve("creature_loot_template", loot_id).items():
            for spell in item_to_spell.get(item, ()):
                for npc in npcs_by_loot[loot_id]:
                    base = heroic_parent.get(npc, npc)
                    s = src(recipes[spell], "m")["n"]
                    prev = s.get(base)
                    heroic = base != npc
                    if not prev or (prev[1] and not heroic) or (prev[1] == heroic and p > prev[0]):
                        s[base] = (p, heroic)
    object_names = {}
    for entry, name, gtype, data1 in q("SELECT entry,name,type,data1 FROM gameobject_template WHERE type IN (3,25)"):
        if not data1:
            continue
        for item, p in loot.resolve("gameobject_loot_template", data1).items():
            for spell in item_to_spell.get(item, ()):
                src(recipes[spell], "o")["o"][entry] = max(p, src(recipes[spell], "o")["o"].get(entry, 0))
                object_names[entry] = name
    container_items = {}
    for (entry,) in q("SELECT DISTINCT entry FROM item_loot_template"):
        for item, p in loot.resolve("item_loot_template", entry).items():
            for spell in item_to_spell.get(item, ()):
                src(recipes[spell], "i")["i"][entry] = max(p, src(recipes[spell], "i")["i"].get(entry, 0))
                container_items[entry] = None
    for entry, name in q("SELECT entry,name FROM item_template"):
        if entry in container_items:
            container_items[entry] = name
    for (zone,) in q("SELECT DISTINCT entry FROM fishing_loot_template"):
        for item, p in loot.resolve("fishing_loot_template", zone).items():
            for spell in item_to_spell.get(item, ()):
                src(recipes[spell], "f")["f"][zone] = p

    # ---- quests
    quests = {}
    for row in q("SELECT entry,Title,QuestLevel,RequiredRaces,RequiredClasses,ZoneOrSort,RewChoiceItemId1,RewChoiceItemId2,RewChoiceItemId3,"
                 "RewChoiceItemId4,RewChoiceItemId5,RewChoiceItemId6,RewItemId1,RewItemId2,RewItemId3,RewItemId4 FROM quest_template"):
        for item in row[6:]:
            for spell in item_to_spell.get(item or 0, ()):
                races = row[3] or 0
                side = "A" if races & ALLIANCE_RACES and not races & HORDE_RACES else (
                    "H" if races & HORDE_RACES and not races & ALLIANCE_RACES else None)
                quests[row[0]] = {"n": row[1] or "", "l": row[2] or 0, "s": side, "npc": set(), "obj": set(),
                                  "c": (row[4] & ALL_CLASSES) if row[4] and row[4] & ALL_CLASSES != ALL_CLASSES else 0,
                                  "sort_h": QUEST_SORT_HOLIDAYS.get(row[5])}
                src(recipes[spell], "q")["q"].add(row[0])
    for table, key in (("creature_questrelation", "npc"), ("gameobject_questrelation", "obj")):
        for entry, quest in q("SELECT id,quest FROM %s" % table) if False else q("SELECT * FROM %s" % table):
            if quest in quests:
                quests[quest][key].add(entry)
    for entry, quest in q("SELECT * FROM creature_involvedrelation"):
        if quest in quests and not quests[quest]["npc"] and not quests[quest]["obj"]:
            quests[quest]["npc"].add(entry)

    # ---- holidays (event creatures / quests)
    events = {}
    for entry, holiday, linked in q("SELECT entry,holiday,linkedTo FROM game_event"):
        events[entry] = (holiday, linked)

    def event_holiday(entry, depth=0):
        info = events.get(entry)
        if not info or depth > 5:
            return None
        if info[0] in HOLIDAYS:
            return HOLIDAYS[info[0]]
        return event_holiday(info[1], depth + 1) if info[1] else None
    guid_holiday = {}
    for guid, event in q("SELECT guid,event FROM game_event_creature"):
        if event > 0 and event_holiday(event):
            guid_holiday[guid] = event_holiday(event)
    quest_holiday = {}
    for quest, event in q("SELECT quest,event FROM game_event_quest"):
        if event > 0 and event_holiday(event):
            quest_holiday[quest] = event_holiday(event)

    # ---- collect relevant ids
    relevant_npcs, relevant_objects = set(), set()
    for spell, r in recipes.items():
        for kind, s in r["src"].items():
            relevant_npcs.update(s["n"].keys())
            relevant_objects.update(s["o"].keys())
        for quest in r["src"].get("q", {}).get("q", ()):
            relevant_npcs.update(quests[quest]["npc"])
            relevant_objects.update(quests[quest]["obj"])
            object_names.update({o: None for o in quests[quest]["obj"] if o not in object_names})

    spawn_entries = defaultdict(list)
    for guid, entry in q("SELECT guid,entry FROM creature_spawn_entry"):
        spawn_entries[guid].append(entry)
    npc_spawns = defaultdict(list)
    npc_holiday_votes = defaultdict(Counter)
    for guid, cid, map_id, x, y, z in q("SELECT guid,id,map,position_x,position_y,position_z FROM creature"):
        for npc in ([cid] if cid else spawn_entries.get(guid, ())):
            if npc in relevant_npcs:
                npc_spawns[npc].append((map_id, x, y, z))
                npc_holiday_votes[npc][guid_holiday.get(guid)] += 1
    go_entries = defaultdict(list)
    for guid, entry in q("SELECT guid,entry FROM gameobject_spawn_entry"):
        go_entries[guid].append(entry)
    obj_spawns = defaultdict(list)
    for guid, oid, map_id, x, y, z in q("SELECT guid,id,map,position_x,position_y,position_z FROM gameobject"):
        for obj in ([oid] if oid else go_entries.get(guid, ())):
            if obj in relevant_objects:
                obj_spawns[obj].append((map_id, x, y, z))
    for entry, name in q("SELECT entry,name FROM gameobject_template"):
        if entry in relevant_objects and (entry not in object_names or not object_names[entry]):
            object_names[entry] = name

    def points_for(spawns):
        by_map, instance = defaultdict(list), Counter()
        for map_id, x, y, z in spawns:
            loc = locate(map_id, x, y, z, areas, maps)
            if loc[0] is None:
                if loc[1]:
                    instance[loc[1]] += 1
                continue
            by_map[(loc[0], loc[3])].append((loc[1], loc[2]))
        points = []
        for (map_file, floor), pts in sorted(by_map.items()):
            mx = sorted(p[0] for p in pts)[len(pts) // 2]
            my = sorted(p[1] for p in pts)[len(pts) // 2]
            best = min(pts, key=lambda p: (p[0] - mx) ** 2 + (p[1] - my) ** 2)
            points.append((map_file, best[0], best[1], floor, len(pts)))
        return points, (instance.most_common(1)[0][0] if instance else None)

    npc_out = {}
    for npc in relevant_npcs:
        tpl = creature_tpl.get(npc)
        if not tpl:
            continue
        points, instance = points_for(npc_spawns.get(npc, ()))
        votes = npc_holiday_votes.get(npc)
        holiday = None
        if votes and len(votes) == 1 and None not in votes:
            holiday = next(iter(votes))
        npc_out[npc] = {"n": tpl[1], "p": points, "z": instance, "s": templates.get(tpl[2]),
                        "h": holiday, "l": (tpl[3], tpl[4])}
    obj_out = {}
    for obj in relevant_objects:
        points, instance = points_for(obj_spawns.get(obj, ()))
        obj_out[obj] = {"n": object_names.get(obj) or ("Object %d" % obj), "p": points, "z": instance}

    # ---- turn drop lists into either per-mob sources or one "world drop" summary
    spawned = {npc for npc, info in npc_out.items() if info["p"] or info["z"]}
    for spell, r in recipes.items():
        m = r["src"].get("m")
        if not m:
            continue
        mobs = {npc: v for npc, v in m["n"].items() if npc in spawned}
        if len(mobs) > WORLD_DROP_NPCS:
            levels = sorted(lvl for npc in mobs for lvl in npc_out[npc]["l"])
            zones = Counter()
            for npc in mobs:
                for p in npc_out[npc]["p"]:
                    zones[p[0]] += 1
            best = sorted(v[0] for v in mobs.values())
            r["world"] = {"lo": levels[len(levels) // 10], "hi": levels[(len(levels) * 9) // 10],
                          "c": best[len(best) // 2], "z": [z for z, _ in zones.most_common(4)], "count": len(mobs)}
            m["n"] = {}
        else:
            m["n"] = dict(sorted(mobs.items(), key=lambda kv: -kv[1][0]))

    # ---- recipe-level faction side (only if every route is a faction-restricted item)
    for r in recipes.values():
        sides = r.get("item_sides", set())
        if len(sides) == 1 and None not in sides and "t" not in r["src"] and "d" not in r["src"]:
            r["side"] = next(iter(sides))

    # drop empty recipes that are not obtainable at all
    used_npcs = set()
    for r in recipes.values():
        for kind, s in r["src"].items():
            used_npcs.update(s["n"].keys())
        for quest in r["src"].get("q", {}).get("q", ()):
            used_npcs.update(quests[quest]["npc"])

    # ---------------------------------------------------------------- emit Lua
    group_ids, groups = {}, []

    def id_list(ids):
        ids = tuple(ids)
        if len(ids) < 3:
            return "{%s}" % ",".join(map(str, ids))
        if ids not in group_ids:
            groups.append(ids)
            group_ids[ids] = len(groups)
        return "G[%d]" % group_ids[ids]

    def container_holiday(entry):
        name = (container_items.get(entry) or "").lower()
        if any(w in name for w in ("gaily wrapped", "ticking present", "smokywood", "winter veil", "festive gift", "gently shaken")):
            return "WINTER_VEIL"
        if "rocket recipes" in name:
            return "LUNAR_FESTIVAL"
        return None

    def recipe_holiday(r):
        """Holiday key when every way to get the recipe is tied to that holiday."""
        if r.get("manual_holiday"):
            return r["manual_holiday"]
        if "world" in r and r["world"]["c"] >= 0.0005:       # ignore 0.01% noise drops
            return None
        tags = set()
        for kind, s in r["src"].items():
            if kind in ("t", "v"):
                ids = [n for n in s["n"] if n in npc_out and (npc_out[n]["p"] or npc_out[n]["z"])]
                tags.update(npc_out[n]["h"] for n in ids)
            elif kind == "q":
                tags.update(quest_holiday.get(x) or quests[x]["sort_h"] for x in s["q"])
            elif kind == "i":
                tags.update(container_holiday(x) for x in s["i"])
            elif s["n"] or s["o"] or s["f"] or s["d"]:
                tags.add(None)
        return next(iter(tags)) if len(tags) == 1 and None not in tags else None

    body = []
    for prof in sorted(PROFESSIONS):
        body.append("[%d]={" % prof)
        for spell in sorted(s for s, r in recipes.items() if r["p"] == prof):
            r = recipes[spell]
            parts = []
            for kind in ("t", "v", "m", "q", "o", "i", "f", "d"):
                s = r["src"].get(kind)
                if not s:
                    continue
                if kind == "t" and s["n"]:
                    parts.append('{t="t",n=%s}' % id_list(sorted(s["n"])))
                elif kind == "v" and s["n"]:
                    ids = sorted(s["n"])
                    lim = [str(n) for n in ids if s["n"][n] == 2]
                    parts.append('{t="v",n=%s%s}' % (id_list(ids), (",l={%s}" % ",".join(lim)) if lim else ""))
                elif kind == "m" and s["n"]:
                    ids = list(s["n"])
                    parts.append('{t="m",n={%s},c={%s}%s}' % (
                        ",".join(map(str, ids)), ",".join(fmt_chance(s["n"][n][0]) for n in ids),
                        (",h={%s}" % ",".join(str(n) for n in ids if s["n"][n][1])) if any(s["n"][n][1] for n in ids) else ""))
                elif kind == "q" and s["q"]:
                    parts.append('{t="q",q={%s}}' % ",".join(map(str, sorted(s["q"]))))
                elif kind == "o" and s["o"]:
                    ids = sorted(s["o"], key=lambda o: -s["o"][o])
                    parts.append('{t="o",o={%s},c={%s}}' % (",".join(map(str, ids)), ",".join(fmt_chance(s["o"][o]) for o in ids)))
                elif kind == "i" and s["i"]:
                    ids = sorted(s["i"], key=lambda o: -s["i"][o])
                    parts.append('{t="i",i={%s},c={%s}}' % (",".join(map(str, ids)), ",".join(fmt_chance(s["i"][o]) for o in ids)))
                elif kind == "f" and s["f"]:
                    names = sorted({area_names.get(z, "#%d" % z) for z in s["f"]})
                    parts.append('{t="f",z={%s}}' % ",".join(lua_string(n) for n in names))
                elif kind == "d" and s["d"]:
                    parts.append('{t="d",d={%s}}' % ",".join(map(str, sorted(s["d"]))))
            if "world" in r:
                w = r["world"]
                parts.append('{t="w",lo=%d,hi=%d,c=%s,cnt=%d,z={%s}}' % (
                    w["lo"], w["hi"], fmt_chance(w["c"]), w["count"], ",".join(lua_string(z) for z in w["z"])))
            fields = ["i=%d" % r["i"], "r=%d" % r["r"]]
            if r["rf"]:
                fields += ["rf=%d" % r["rf"], "rr=%d" % r["rr"]]
            if r["price"] and "v" in r["src"]:
                fields.append("pr=%d" % r["price"])
            if r["side"]:
                fields.append('fs="%s"' % r["side"])
            extra_items = sorted(i for i in r.get("items", ()) if i != r["i"])
            if extra_items:
                fields.append("ia={%s}" % ",".join(map(str, extra_items)))
            created = spells.get(spell, (0, 0, 0, 0))[3]
            if created:
                fields.append("ci=%d" % created)
            classes = sla_classes.get(spell, ALL_CLASSES) or ALL_CLASSES
            if "t" not in r["src"] and "d" not in r["src"] and r.get("item_classes"):
                classes &= r["item_classes"]
            if classes and classes != ALL_CLASSES:
                fields.append("cl=%d" % classes)
            holiday = recipe_holiday(r)
            if holiday:
                fields.append('hd="%s"' % holiday)
            body.append("[%d]={%s,s={%s}}," % (spell, ",".join(fields), ",".join(parts)))
        body.append("},")

    npc_lines = []
    for npc in sorted(used_npcs):
        info = npc_out.get(npc)
        if not info:
            continue
        f = ["n=%s" % lua_string(info["n"])]
        if info["p"]:
            f.append("p={%s}" % ",".join(
                ('{m=%s,x=%.3f,y=%.3f%s}' % (lua_string(m), x, y, (",f=%d" % fl) if fl else ""))
                for m, x, y, fl, _ in info["p"]))
        if info["z"]:
            f.append("z=%s" % lua_string(info["z"]))
        if info["s"]:
            f.append('s="%s"' % info["s"])
        if info["h"]:
            f.append('h="%s"' % info["h"])
        npc_lines.append("[%d]={%s}," % (npc, ",".join(f)))
    obj_lines = []
    for obj in sorted(obj_out):
        info = obj_out[obj]
        f = ["n=%s" % lua_string(info["n"])]
        if info["p"]:
            f.append("p={%s}" % ",".join('{m=%s,x=%.3f,y=%.3f%s}' % (lua_string(m), x, y, (",f=%d" % fl) if fl else "")
                                         for m, x, y, fl, _ in info["p"]))
        if info["z"]:
            f.append("z=%s" % lua_string(info["z"]))
        obj_lines.append("[%d]={%s}," % (obj, ",".join(f)))
    quest_lines = []
    for quest in sorted(quests):
        info = quests[quest]
        f = ["n=%s" % lua_string(info["n"]), "l=%d" % info["l"]]
        if info["npc"]:
            f.append("g={%s}" % ",".join(map(str, sorted(info["npc"]))))
        if info["obj"]:
            f.append("go={%s}" % ",".join(map(str, sorted(info["obj"]))))
        if info["s"]:
            f.append('s="%s"' % info["s"])
        if quest_holiday.get(quest) or info["sort_h"]:
            f.append('h="%s"' % (quest_holiday.get(quest) or info["sort_h"]))
        if info["c"]:
            f.append("c=%d" % info["c"])
        quest_lines.append("[%d]={%s}," % (quest, ",".join(f)))
    used_factions = sorted({r["rf"] for r in recipes.values() if r["rf"]})

    version = q("SELECT version FROM db_version").fetchone()[0]
    out = ["-- Generated by tools/build_catalog.py from CMaNGOS %s" % version,
           "-- and WotLK 3.3.5a (12340) DBC files. Do not edit by hand.",
           "local G = {"]
    out += ["{%s}," % ",".join(map(str, g)) for g in groups]
    out += ["}", "RecipeAtlasData = { P = {"] + body
    out += ["}, N = {"] + npc_lines + ["}, O = {"] + obj_lines + ["}, Q = {"] + quest_lines
    out += ["}, I = {"] + ["[%d]=%s," % (i, lua_string(n)) for i, n in sorted(container_items.items())]
    out += ["}, F = {"] + ["[%d]=%s," % (f, lua_string(faction_names.get(f, "#%d" % f))) for f in used_factions]
    out += ["} }", "G = nil"]
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")

    counts = Counter(PROFESSIONS[r["p"]] for r in recipes.values())
    kinds = Counter(k for r in recipes.values() for k in r["src"]) + Counter("w" for r in recipes.values() if "world" in r)
    print("DB:", version)
    print("Recipes:", len(recipes), dict(counts))
    print("Recipes by source:", dict(kinds))
    print("Without source:", sum(1 for r in recipes.values() if not r["src"]))
    print("NPCs:", len(npc_lines), "with points:", sum(1 for n in used_npcs if npc_out.get(n, {}).get("p")),
          "objects:", len(obj_lines), "quests:", len(quest_lines), "shared lists:", len(groups))


if __name__ == "__main__":
    main()
