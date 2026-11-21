#!/usr/bin/env python3
"""Точечно правит координаты деталей в assets/CorpaLab.rbxm без Studio и Rojo.

Что делает (идемпотентно — результат не зависит от числа запусков):
  * «Витрина 8» (стенд с автомобилем) переносится ближе ко входу в каждом из шести секторов;
  * два «Терминала рейтинга» переносятся от краёв зала к его центру.

Скрипт читает бинарный rbxm, меняет только позиции в свойстве CFrame и пишет изменённый блок без сжатия
(формат это допускает). Перед записью проверяется, что новые места свободны, а после — что все остальные
свойства всех деталей остались прежними.

Запуск: python3 scripts/patch_scene.py [--check]
"""
import argparse
import collections
import math
import struct
import sys
from pathlib import Path

SCENE = Path(__file__).resolve().parents[1] / "assets" / "CorpaLab.rbxm"

# Новое место автомобильного стенда в системе координат сектора (за начало берётся «Вход 0N»), студы.
CAR_STAND_LOCAL = (-13.0, -2.0)
# Терминалы рейтинга: |x| в мировых координатах (стояли на 68).
RANKING_X = 24.0


def lz4_block(data: bytes, out_size: int) -> bytes:
    out = bytearray()
    i = 0
    while i < len(data):
        token = data[i]
        i += 1
        literal = token >> 4
        if literal == 15:
            while True:
                extra = data[i]
                i += 1
                literal += extra
                if extra != 255:
                    break
        out += data[i : i + literal]
        i += literal
        if i >= len(data):
            break
        offset = data[i] | (data[i + 1] << 8)
        i += 2
        length = token & 15
        if length == 15:
            while True:
                extra = data[i]
                i += 1
                length += extra
                if extra != 255:
                    break
        for _ in range(length + 4):
            out.append(out[-offset])
    assert len(out) == out_size, "Ошибка распаковки LZ4"
    return bytes(out)


class Chunk:
    def __init__(self, name: bytes, raw: bytes, data: bytes):
        self.name, self.raw, self.data = name, raw, data

    def replace(self, data: bytes) -> None:
        self.data = data
        self.raw = self.name + struct.pack("<III", 0, len(data), 0) + data


def parse_chunks(buf: bytes):
    assert buf[:8] == b"<roblox!", "Это не бинарный rbxm"
    pos = 32
    chunks = []
    while pos < len(buf):
        name = buf[pos : pos + 4]
        clen, ulen = struct.unpack("<II", buf[pos + 4 : pos + 12])
        body = clen if clen else ulen
        raw = buf[pos : pos + 16 + body]
        data = buf[pos + 16 : pos + 16 + body]
        if clen:
            data = lz4_block(data, ulen)
        chunks.append(Chunk(name, raw, data))
        pos += 16 + body
        if name == b"END\0":
            break
    return buf[:32], chunks


def interleaved(raw: bytes):
    n = len(raw) // 4
    return [(raw[i] << 24) | (raw[n + i] << 16) | (raw[2 * n + i] << 8) | raw[3 * n + i] for i in range(n)]


def interleave(values) -> bytes:
    n = len(values)
    out = bytearray(4 * n)
    for i, v in enumerate(values):
        out[i], out[n + i], out[2 * n + i], out[3 * n + i] = v >> 24, (v >> 16) & 255, (v >> 8) & 255, v & 255
    return bytes(out)


def unzigzag(v: int) -> int:
    return (v >> 1) ^ -(v & 1)


def refs(raw: bytes):
    out, acc = [], 0
    for v in interleaved(raw):
        acc += unzigzag(v)
        out.append(acc)
    return out


def floats(raw: bytes):
    out = []
    for v in interleaved(raw):
        v = ((v >> 1) | (v << 31)) & 0xFFFFFFFF
        out.append(struct.unpack("<f", struct.pack("<I", v))[0])
    return out


def pack_floats(values) -> bytes:
    words = []
    for f in values:
        v = struct.unpack("<I", struct.pack("<f", f))[0]
        words.append(((v << 1) | (v >> 31)) & 0xFFFFFFFF)
    return interleave(words)


class Scene:
    def __init__(self, path: Path):
        self.header, self.chunks = parse_chunks(path.read_bytes())
        self.classes = {}  # id -> (имя, [id экземпляров])
        self.props = collections.defaultdict(dict)  # id класса -> имя -> (Chunk, смещение данных, тип)
        self.parents = {}
        for chunk in self.chunks:
            d = chunk.data
            if chunk.name == b"INST":
                cid, nlen = struct.unpack("<II", d[:8])
                name = d[8 : 8 + nlen].decode()
                p = 8 + nlen + 1
                (count,) = struct.unpack("<I", d[p : p + 4])
                self.classes[cid] = (name, refs(d[p + 4 : p + 4 + count * 4]))
            elif chunk.name == b"PRNT":
                (count,) = struct.unpack("<I", d[1:5])
                kids, owners = refs(d[5 : 5 + count * 4]), refs(d[5 + count * 4 : 5 + count * 8])
                self.parents = dict(zip(kids, owners))
            elif chunk.name == b"PROP":
                cid, nlen = struct.unpack("<II", d[:8])
                pname = d[8 : 8 + nlen].decode()
                self.props[cid][pname] = (chunk, 9 + nlen, d[8 + nlen])
        self.where = {}  # id экземпляра -> (id класса, индекс)
        for cid, (_, ids) in self.classes.items():
            for index, ref in enumerate(ids):
                self.where[ref] = (cid, index)

    def strings(self, cid: int, pname: str):
        chunk, off, _ = self.props[cid][pname]
        d, out = chunk.data, []
        for _ in self.classes[cid][1]:
            (length,) = struct.unpack("<I", d[off : off + 4])
            out.append(d[off + 4 : off + 4 + length].decode("utf-8", "replace"))
            off += 4 + length
        return out

    def cframes(self, cid: int):
        """Возвращает список [поворот, x, y, z] по экземплярам класса."""
        chunk, off, _ = self.props[cid]["CFrame"]
        d, n = chunk.data, len(self.classes[cid][1])
        rotations = []
        for _ in range(n):
            ident = d[off]
            off += 1
            if ident == 0:
                rotations.append(struct.unpack("<9f", d[off : off + 36]))
                off += 36
            else:
                rotations.append(ident)
        xs, ys, zs = (floats(d[off + k * n * 4 : off + (k + 1) * n * 4]) for k in range(3))
        return [[rotations[i], xs[i], ys[i], zs[i]] for i in range(n)]

    def sizes(self, cid: int):
        chunk, off, _ = self.props[cid]["size"]
        d, n = chunk.data, len(self.classes[cid][1])
        xs, ys, zs = (floats(d[off + k * n * 4 : off + (k + 1) * n * 4]) for k in range(3))
        return list(zip(xs, ys, zs))

    def write_cframes(self, cid: int, frames) -> None:
        chunk, off, _ = self.props[cid]["CFrame"]
        d, n = chunk.data, len(self.classes[cid][1])
        head, body = d[:off], bytearray()
        for rotation, *_ in frames:
            if isinstance(rotation, int):
                body.append(rotation)
            else:
                body.append(0)
                body += struct.pack("<9f", *rotation)
        for k in range(1, 4):
            body += pack_floats([frame[k] for frame in frames])
        chunk.replace(bytes(head + body))

    def save(self, path: Path) -> None:
        path.write_bytes(self.header + b"".join(chunk.raw for chunk in self.chunks))


def rotation_matrix(value):
    # В сцене встречаются только единичный поворот (идентификатор 2) и явные матрицы.
    if isinstance(value, int):
        if value != 2:
            raise ValueError(f"Неожиданный идентификатор поворота {value}")
        return (1, 0, 0, 0, 1, 0, 0, 0, 1)
    return value


def box_xz(r, cx: float, cz: float, hx: float, hz: float):
    """Прямоугольник детали на плане: центр, оси (по столбцам матрицы поворота) и полуразмеры."""
    return (cx, cz, (r[0], r[6]), (r[2], r[8]), hx, hz)


def boxes_overlap(a, b) -> bool:
    """Пересечение двух повёрнутых прямоугольников (теорема о разделяющей оси)."""
    axes = [a[2], a[3], b[2], b[3]]
    for ax, az in axes:
        length = math.hypot(ax, az)
        ax, az = ax / length, az / length

        def radius(box):
            return (
                abs(box[2][0] * ax + box[2][1] * az) * box[4] + abs(box[3][0] * ax + box[3][1] * az) * box[5]
            )

        distance = abs((b[0] - a[0]) * ax + (b[1] - a[1]) * az)
        if distance >= radius(a) + radius(b):
            return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="только проверить, ничего не записывая")
    args = parser.parse_args()

    scene = Scene(SCENE)
    part_cid = next(cid for cid, (name, _) in scene.classes.items() if name == "Part")
    spawn_cid = next(cid for cid, (name, _) in scene.classes.items() if name == "SpawnLocation")
    models = {ref: scene.strings(cid, "Name")[i] for cid, (n, ids) in scene.classes.items() if n == "Model" for i, ref in enumerate(ids)}
    names = scene.strings(part_cid, "Name")
    frames = scene.cframes(part_cid)
    sizes = scene.sizes(part_cid)
    spawn_frames = scene.cframes(spawn_cid)
    spawn_names = scene.strings(spawn_cid, "Name")
    original = [list(frame) for frame in frames]
    part_refs = scene.classes[part_cid][1]
    spawn_refs = scene.classes[spawn_cid][1]

    changed = []
    # --- Автомобильные стенды ---
    for index, name in enumerate(spawn_names):
        sector = scene.parents[spawn_refs[index]]
        stand = next(
            i for i, ref in enumerate(part_refs) if names[i] == "Витрина 8" and scene.parents[ref] == sector
        )
        rot, ox, oy, oz = spawn_frames[index]
        m = rotation_matrix(rot)
        lx, lz = CAR_STAND_LOCAL
        # Локальные оси сектора: x -> столбец 0, z -> столбец 2 матрицы поворота входа.
        wx = ox + m[0] * lx + m[2] * lz
        wz = oz + m[6] * lx + m[8] * lz
        pad = (sizes[stand][0] / 2 + 0.8, sizes[stand][2] / 2 + 0.8)
        stand_box = box_xz(rotation_matrix(frames[stand][0]), wx, wz, pad[0], pad[1])
        # Проверка свободного места: ни одна деталь сектора выше пола и ниже 6 студов не пересекает площадку.
        for i, ref in enumerate(part_refs):
            if scene.parents[ref] != sector or i == stand:
                continue
            sx, sy, sz = sizes[i]
            y = frames[i][2]
            if y + sy / 2 < 0.25 or y - sy / 2 > 6:
                continue
            r = rotation_matrix(frames[i][0])
            if abs(r[4]) > 0.99:
                other = box_xz(r, frames[i][1], frames[i][3], sx / 2, sz / 2)
            else:  # наклонная деталь — берём охватывающий прямоугольник по осям мира
                other = box_xz(
                    (1, 0, 0, 0, 1, 0, 0, 0, 1),
                    frames[i][1],
                    frames[i][3],
                    abs(r[0]) * sx / 2 + abs(r[1]) * sy / 2 + abs(r[2]) * sz / 2,
                    abs(r[6]) * sx / 2 + abs(r[7]) * sy / 2 + abs(r[8]) * sz / 2,
                )
            if boxes_overlap(stand_box, other):
                sys.exit(f"{models[sector]}: место занято деталью «{names[i]}» — перенос отменён")
        frames[stand][1], frames[stand][3] = wx, wz
        changed.append(f"{models[sector]}: Витрина 8 -> ({wx:.1f}, {frames[stand][2]:.1f}, {wz:.1f})")

    # --- Терминалы рейтинга ---
    for i, name in enumerate(names):
        if name == "Терминал рейтинга":
            frames[i][1] = math.copysign(RANKING_X, frames[i][1])
            changed.append(f"Терминал рейтинга -> x={frames[i][1]:.1f}")

    for line in changed:
        print(line)
    if args.check:
        return 0
    scene.write_cframes(part_cid, frames)
    staging = SCENE.with_suffix(".new")
    scene.save(staging)

    # --- Проверка результата: всё, кроме намеченных позиций, осталось прежним ---
    after = Scene(staging)
    new_frames = after.cframes(part_cid)
    def close(a, b) -> bool:
        return a[0] == b[0] and all(abs(x - y) < 1e-3 for x, y in zip(a[1:], b[1:]))

    differing = [names[i] for i in range(len(frames)) if not close(new_frames[i], frames[i])]
    assert not differing, f"Не совпало после записи: {differing[:3]}"
    moved = {names[i] for i in range(len(frames)) if original[i][1:] != frames[i][1:]}
    assert moved <= {"Витрина 8", "Терминал рейтинга"}, moved
    assert after.sizes(part_cid) == sizes
    assert after.strings(part_cid, "Name") == names
    staging.replace(SCENE)
    print(f"Готово: изменено деталей — {sum(1 for i in range(len(frames)) if original[i][1:] != frames[i][1:])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
