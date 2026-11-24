#!/usr/bin/env python3
"""Convert the OSM snapshot into metre-based Godot chunk inputs and an atlas."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import random
import re
from urllib.request import Request, urlopen
from xml.etree import ElementTree as ET

from PIL import Image, ImageDraw
from shapely import constrained_delaunay_triangles, make_valid
from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import nearest_points, polygonize, unary_union

ROOT = Path(__file__).resolve().parents[1]
BOUNDS = (121.480, 31.225, 121.515, 31.247)
ORIGIN = (121.498, 31.236)
SIZE = 256
LAT_M = 111_312
LON_M = 111_319 * math.cos(math.radians(ORIGIN[1]))
URL = 'https://api.openstreetmap.org/api/0.6/map?bbox=' + ','.join(map(str, BOUNDS))

# IDs distinguish landmark geometry from surrounding podiums and other historic façades.
LANDMARKS = [
    ('pearl', '东方明珠', 'Oriental Pearl Tower', '40778038', (121.49522, 31.24194)),
    ('shanghai', '上海中心大厦', 'Shanghai Tower', '165792123', (121.50106, 31.23553)),
    ('jinmao', '金茂大厦', 'Jin Mao Tower', '376075961', (121.50093, 31.23711)),
    ('swfc', '上海环球金融中心', 'World Financial Center', '10691100', (121.50295, 31.23673)),
    ('convention', '上海国际会议中心', 'International Convention Center', '40778072', (121.49284, 31.24131)),
    ('peace', '和平饭店', 'Peace Hotel', '177998986', (121.48455, 31.24114)),
    ('customs', '江海关大楼', 'Customs House', '476149343', (121.48532, 31.23872)),
    ('bridge', '外白渡桥', 'Waibaidu Bridge', '27498117', (121.48575, 31.24531)),
    ('wharf', '十六铺码头', 'Shiliupu Wharf', '530696824', (121.49220, 31.23140)),
    ('bund', '外滩', 'The Bund', '', (121.48681, 31.24007)),
    ('nanjing', '南京东路', 'East Nanjing Road', '', (121.48348, 31.24062)),
    ('green', '陆家嘴中心绿地', 'Lujiazui Central Green', '', (121.49962, 31.24013)),
    ('century', '世纪大道', 'Century Avenue', '', (121.50667, 31.23392)),
    ('mall', '正大广场', 'Super Brand Mall', '', (121.49586, 31.23907)),
    ('promenade', '浦东滨江步道', 'Pudong Riverside', '', (121.49278, 31.23996)),
    ('creek', '苏州河入江口', 'Suzhou Creek Mouth', '', (121.48740, 31.24555)),
    ('yanan', '延安东路', 'East Yan’an Road', '', (121.48421, 31.23322)),
    ('ring', '陆家嘴环路', 'Lujiazui Ring Road', '', (121.49682, 31.24037)),
    ('zhongshan', '中山东一路', 'East Zhongshan No. 1 Road', '', (121.48654, 31.23862)),
    ('riverside', '滨江大道', 'Riverside Avenue', '', (121.49166, 31.24023)),
]
DRIVE = {'motorway': 13, 'trunk': 12, 'primary': 11, 'secondary': 9,
         'tertiary': 7, 'residential': 6, 'unclassified': 6, 'service': 4,
         'living_street': 4, 'motorway_link': 6, 'trunk_link': 6,
         'primary_link': 6, 'secondary_link': 5, 'tertiary_link': 5}
WALK = {'footway': 1.8, 'pedestrian': 4.0, 'cycleway': 2.2, 'path': 1.35,
        'steps': 1.8, 'track': 2.8}
REPLACE = {row[3] for row in LANDMARKS[:6]}
REPLACE.update(('177998987', '177998982'))


def metre(lon, lat):
    return ((float(lon) - ORIGIN[0]) * LON_M, (ORIGIN[1] - float(lat)) * LAT_M)


def xy(point):
    return [round(point[0], 2), round(point[1], 2)]


def tags(item):
    return {t.get('k'): t.get('v') for t in item.findall('tag')}


def parts(shape, kind='Polygon'):
    if shape.is_empty:
        return
    if shape.geom_type == kind:
        yield shape
    elif hasattr(shape, 'geoms'):
        for part in shape.geoms:
            yield from parts(part, kind)


def triangles(shape):
    return [round(value, 2) for p in parts(shape)
            for tri in constrained_delaunay_triangles(p).geoms
            for point in list(tri.exterior.coords)[:3] for value in point[:2]]


def stable_height(t, ident, historic):
    for key, scale in [('height', 1), ('building:levels', 3.25)]:
        match = re.fullmatch(r'\s*(\d+(?:\.\d+)?)\s*(m|ft|feet|\')?\s*', t.get(key, ''))
        if match:
            value = float(match[1]) * scale * (0.3048 if match[2] in ('ft', 'feet', "'") else 1)
            if value > 0:
                return min(value, 640), key
    default = 11 if historic else 15
    if t.get('building') in ('garage', 'shed', 'toilets', 'roof', 'kiosk'):
        return 3.5, 'estimated'
    return default + ((int(ident) * 31) % 9) * 2.2, 'estimated'


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')


def route_from(ids, ways, nodes):
    first = [nodes[n] for n in ways[ids[0]][0]]
    for ident in ids[1:]:
        section = [nodes[n] for n in ways[ident][0]]
        if math.dist(first[-1], section[-1]) < math.dist(first[-1], section[0]):
            section.reverse()
        first.extend(section[1:] if first[-1] == section[0] else section)
    return [xy(p) for p in LineString(first).simplify(1.7).coords]


def signal_points(root, ways, nodes, boundary):
    mapped = {int(item.get('id')) for item in root.findall('node')
              if tags(item).get('highway') == 'traffic_signals'
              and boundary.covers(Point(nodes[int(item.get('id'))]))}
    signals = {}
    cells = set()
    for refs, t in sorted(ways.values(), key=lambda way: -DRIVE.get(way[1].get('highway'), 0)):
        width = DRIVE.get(t.get('highway', ''), 0)
        if not width or t.get('tunnel', 'no') != 'no' or t.get('bridge', 'no') != 'no':
            continue
        for i, ref in enumerate(refs):
            if ref not in mapped or ref in signals:
                continue
            a = nodes.get(refs[max(0, i - 1)])
            b = nodes.get(refs[min(len(refs) - 1, i + 1)])
            if a is None or b is None or math.dist(a, b) < 1:
                continue
            pos = nodes[ref]
            cell = (round(pos[0] / 5), round(pos[1] / 5))
            if cell in cells:
                continue
            cells.add(cell)
            yaw = math.atan2(a[0] - b[0], a[1] - b[1])
            signals[ref] = [*xy(pos), round(yaw, 3), width]
    return list(signals.values())


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument('--fetch', action='store_true')
    cli.add_argument('--source', type=Path, default=ROOT / 'maps/source/shanghai.osm')
    cli.add_argument('--output', type=Path, default=ROOT / 'maps')
    args = cli.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if args.fetch:
        req = Request(URL, headers={'User-Agent': 'ShanghaiOpenWorld/0.1 (manual development snapshot)'})
        with urlopen(req, timeout=120) as response:
            response_data = response.read()
        ET.fromstring(response_data)
        args.source.parent.mkdir(parents=True, exist_ok=True)
        args.source.write_bytes(response_data)
    raw = args.source.read_bytes()
    root = ET.fromstring(raw)
    nodes = {int(item.get('id')): metre(item.get('lon'), item.get('lat')) for item in root.findall('node')}
    ways = {item.get('id'): ([int(n.get('ref')) for n in item.findall('nd')], tags(item))
            for item in root.findall('way')}
    west, south = metre(BOUNDS[0], BOUNDS[1])
    east, north = metre(BOUNDS[2], BOUNDS[3])
    boundary = box(west, north, east, south)
    tiles = {}
    for x in range(math.floor(west / SIZE), math.ceil(east / SIZE)):
        for z in range(math.floor(north / SIZE), math.ceil(south / SIZE)):
            section = box(x * SIZE, z * SIZE, (x + 1) * SIZE, (z + 1) * SIZE)
            tiles[x, z] = (section.intersection(boundary), defaultdict(list))

    def distribute(kind, shape, prefix=None):
        minx, minz, maxx, maxz = shape.bounds if not shape.is_empty else (0, 0, -1, -1)
        for x in range(math.floor(minx / SIZE), math.floor(maxx / SIZE) + 1):
            for z in range(math.floor(minz / SIZE), math.floor(maxz / SIZE) + 1):
                if (x, z) not in tiles:
                    continue
                section, bucket = tiles[x, z]
                mesh = triangles(shape.intersection(section))
                if mesh:
                    if prefix is None:
                        bucket[kind].extend(mesh)
                    else:
                        bucket[kind].append([*prefix, mesh])

    river, parks, graphics = [], [], []
    buildings, roads, footways = [], [], []
    counts = Counter()
    for ident, (refs, t) in ways.items():
        points = [nodes.get(ref) for ref in refs]
        if len(points) < 2 or any(p is None for p in points):
            continue
        closed = len(points) > 3 and refs[0] == refs[-1]
        polygon = None
        if closed and (t.get('natural') == 'water' or 'building' in t or t.get('leisure') in ('park', 'garden', 'pitch') or t.get('landuse') in ('grass', 'recreation_ground') or t.get('natural') == 'wood'):
            polygon = make_valid(Polygon(points)).intersection(boundary)
            if polygon.is_empty:
                continue
            if t.get('natural') == 'water':
                river.extend(parts(polygon))
            elif 'building' in t and t['building'] != 'no':
                if ident not in REPLACE and t.get('underground') != 'yes' and not t.get('location') == 'underground':
                    buildings.append((polygon, ident, t))
            else:
                parks.extend(parts(polygon))
        highway = t.get('highway', '')
        if highway not in DRIVE and highway not in WALK:
            continue
        if t.get('tunnel', 'no') != 'no' or t.get('location') == 'underground' or t.get('covered') == 'yes' or t.get('area') == 'yes':
            continue
        road = LineString(points)
        if not road.intersects(boundary) or road.length < 1:
            continue
        bridge = t.get('bridge', 'no') != 'no'
        try:
            layer = int(t.get('layer', '0'))
        except ValueError:
            layer = 0
        if not bridge and layer < 0:
            continue
        width = DRIVE.get(highway, WALK.get(highway))
        tags_width = re.match(r'^([0-9]+(?:\.[0-9]+)?)(?: m)?$', t.get('width', ''))
        if tags_width:
            width = min(25, max(1.3, float(tags_width[1])))
        altitude = 3.6 if ident == '27498117' else (max(1, layer) * 3.3 if bridge else 0.0)
        is_drive = highway in DRIVE
        graphics.append((road, width, is_drive, altitude, ident, highway))
        track = roads if is_drive else footways
        for piece in parts(road.intersection(boundary), 'LineString'):
            if piece.length < 8 or bridge:
                continue
            if t.get('oneway') == '-1':
                piece = LineString(list(piece.coords)[::-1])
            track.append([ident, round(width, 2), int(t.get('oneway') in ('yes', '1', '-1') or t.get('junction') == 'roundabout'), [xy(p) for p in piece.coords], highway])

    # Multipolygon parks/water where complete member rings are present in the snapshot.
    for rel in root.findall('relation'):
        t = tags(rel)
        if t.get('type') != 'multipolygon' or not (t.get('natural') == 'water' or t.get('leisure') in ('park', 'garden')):
            continue
        rings = defaultdict(list)
        for member in rel.findall('member'):
            if member.get('ref') not in ways or member.get('type') != 'way':
                continue
            ids = ways[member.get('ref')][0]
            if len(ids) > 1 and all(node in nodes for node in ids):
                rings[member.get('role')].append(LineString([nodes[node] for node in ids]))
        outer = unary_union(list(polygonize(rings['outer'])))
        inner = unary_union(list(polygonize(rings['inner'])))
        target = river if t.get('natural') == 'water' else parks
        target.extend(parts(outer.difference(inner).intersection(boundary)))

    water = unary_union(river)
    green = unary_union(parks).difference(water)
    for section, bucket in tiles.values():
        bucket['ground'] = triangles(section.difference(water))
        bucket['water'] = triangles(section.intersection(water))
        bucket['park'] = triangles(section.intersection(green))

    for road, width, is_drive, altitude, ident, highway in sorted(graphics, key=lambda row: row[2]):
        rank = 3 if highway in ('motorway', 'trunk', 'primary') else (2 if width >= 6 else 1)
        road_shape = road.buffer(width * 0.5, cap_style='round', join_style='round').simplify(0.14)
        clipped = road_shape if altitude > 0 else road_shape.difference(water)
        if is_drive:
            curb = road.buffer(width * 0.5 + 1.1, cap_style='round', join_style='round').simplify(0.22)
            distribute('road', curb if altitude > 0 else curb.difference(water), [0, altitude + 0.022])
        distribute('road', clipped, [rank if is_drive else 4, altitude + 0.036 + rank * 0.003])
        if altitude > 0:
            distribute('deck', clipped, [altitude + 0.05])
            if ident != '27498117':
                d = 6
                while d < road.length - 3:
                    point = road.interpolate(d)
                    if boundary.contains(point) and not water.covers(point):
                        tile = (math.floor(point.x / SIZE), math.floor(point.y / SIZE))
                        tiles[tile][1]['supports'].append([*xy(point.coords[0]), altitude])
                    d += 25 if is_drive else 19
        if is_drive and width >= 6:
            phase = 0.5 + int(ident) % 7
            d = phase
            while d + 3 < road.length:
                a, b = road.interpolate(d), road.interpolate(d + 2.4)
                if boundary.contains(a) and (altitude > 0 or not water.covers(a)):
                    tile = (math.floor(a.x / SIZE), math.floor(a.y / SIZE))
                    tiles[tile][1]['marks'].append([*xy(a.coords[0]), *xy(b.coords[0]), altitude + 0.063])
                d += 9
        if is_drive and width >= 7 and road.length > 25 and altitude == 0:
            d = 10 + int(ident) % 13
            while d + 2 < road.length:
                a, b = road.interpolate(d), road.interpolate(d + 1)
                v = (b.x - a.x, b.y - a.y)
                if math.hypot(*v) > 0.2:
                    pole = Point(a.x - v[1] * (width / 2 + 0.65), a.y + v[0] * (width / 2 + 0.65))
                    if boundary.contains(pole) and not water.covers(pole):
                        tile = (math.floor(pole.x / SIZE), math.floor(pole.y / SIZE))
                        tiles[tile][1]['lamps'].append([*xy(pole.coords[0]), round(math.atan2(v[0], v[1]), 2)])
                d += 34

    randomizer = random.Random(31526)
    for section, bucket in tiles.values():
        if not green.intersects(section):
            continue
        x0, z0, x1, z1 = section.bounds
        for x in range(int(x0) + 4, int(x1), 12):
            for z in range(int(z0) + 4, int(z1), 12):
                p = Point(x + randomizer.uniform(-3, 3), z + randomizer.uniform(-3, 3))
                if green.contains(p):
                    bucket['trees'].append([*xy(p.coords[0]), round(randomizer.uniform(0.75, 1.35), 2)])

    for shape, ident, t in buildings:
        for polygon in parts(shape.simplify(0.20, preserve_topology=True)):
            if polygon.area < 7:
                continue
            center = polygon.representative_point()
            if not boundary.contains(center) or water.contains(center):
                continue
            historic = center.x < -825 and center.y < 210
            height, basis = stable_height(t, ident, historic)
            counts['height_' + basis] += 1
            t_style = int(ident) % 5 + (5 if historic else 0)
            tile = (math.floor(center.x / SIZE), math.floor(center.y / SIZE))
            rings = [[xy(p) for p in list(ring.coords)[:-1]] for ring in (polygon.exterior, *polygon.interiors)]
            tiles[tile][1]['buildings'].append([ident, round(height, 2), t_style, rings, triangles(polygon)])
            if height > 52 or (height >= 23 and center.x < -900 and abs(center.y) < 530):
                simplified = polygon.simplify(2.8)
                tiles[tile][1]['skyline'].append([ident, round(height, 2), t_style, [[xy(p) for p in list(simplified.exterior.coords)[:-1]]], triangles(simplified)])

    landmarks = []
    for key, zh, en, ident, position in LANDMARKS:
        point = metre(*position)
        if ident.isdigit() and int(ident) in nodes and key in ('customs', 'wharf'):
            point = nodes[int(ident)]
        landmarks.append([key, zh, en, xy(point)])
    tunnel = route_from(('479210212','484295023','484295022','479210211','484295019','484295016','484295017'), ways, nodes)
    ferry = route_from(('44780674',), ways, nodes)
    docks = [xy(nearest_points(water.boundary, Point(p))[0].coords[0]) for p in (ferry[0], ferry[-1])]

    inputs = args.output / 'source/chunks'
    inputs.mkdir(parents=True, exist_ok=True)
    valid = set()
    for (x, z), (_, bucket) in tiles.items():
        key = f'{x}_{z}'
        path = inputs / f'{key}.json'
        valid.add(path)
        write_json(path, bucket)
        counts.update({kind: len(bucket[kind]) for kind in ('buildings','trees','lamps')})
    for path in inputs.glob('*.json'):
        if path not in valid:
            path.unlink()

    # Original atlas styling. The north-up atlas is aligned to the same metre coordinates.
    width_px = 1536
    height_px = round(width_px * (south - north) / (east - west))
    atlas = Image.new('RGB', (width_px, height_px), '#1c2a35')
    draw = ImageDraw.Draw(atlas)
    def px(p):
        return ((p[0] - west) * width_px / (east - west), (p[1] - north) * height_px / (south - north))
    def paint(shape, color, hole):
        for p in parts(shape):
            draw.polygon([px(q) for q in p.exterior.coords], fill=color)
            for interior in p.interiors:
                draw.polygon([px(q) for q in interior.coords], fill=hole)
    paint(green, '#29473f', '#1c2a35')
    paint(water, '#09394b', '#1c2a35')
    for shape, _, _ in buildings:
        paint(shape, '#31404b', '#1c2a35')
    for road, width, is_drive, altitude, _, highway in sorted(graphics, key=lambda row: (row[2], row[1])):
        for piece in parts(road.intersection(boundary if altitude else boundary.difference(water)), 'LineString'):
            color = '#8b7770' if highway in ('primary','trunk') else ('#536775' if is_drive else '#374e55')
            draw.line([px(q) for q in piece.coords], fill=color, width=max(1, round(width * 0.37)), joint='curve')
    draw.line([px(p) for p in tunnel], fill='#536162', width=1)
    atlas.save(args.output / 'atlas.png', optimize=True)
    stats = dict(counts, chunks=len(tiles), roads=len(roads), pedestrian_paths=len(footways), area_km2=round(boundary.area / 1e6, 3))
    write_json(args.output / 'city.json', {
        'bounds': [west, north, east, south], 'tile_size': SIZE,
        'tiles': [f'{x}_{z}' for x, z in tiles], 'landmarks': landmarks,
        'roads': roads, 'walkways': footways, 'signals': signal_points(root, ways, nodes, boundary),
        'tunnel': tunnel, 'ferry': ferry, 'ferry_docks': docks,
        'spawn': xy(metre(121.49552, 31.24068)),
        'bridge': [xy(nodes[n]) for n in ways['27498117'][0]],
        'water': [[[xy(q) for q in p.exterior.coords], *[[xy(q) for q in ring.coords] for ring in p.interiors]] for p in parts(water)],
        'attribution': '© OpenStreetMap contributors — ODbL 1.0',
        'osm_source': URL, 'osm_sha256': hashlib.sha256(raw).hexdigest(), 'stats': stats,
    })
    print(json.dumps(stats, ensure_ascii=False))


if __name__ == '__main__':
    main()
