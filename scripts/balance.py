#!/usr/bin/env python3
"""Симуляция темпа прогресса. Параметры должны совпадать с Economy.luau и Catalog.luau.

Запуск: python3 scripts/balance.py [секунд на контейнер]
Печатает: ожидаемую выручку и цену заказа по уровням, затем ход «жадного» игрока,
который покупает самый дешёвый доступный перк. Нужен только для настройки чисел.
"""
import random
import sys

SECONDS_PER_CONTAINER = float(sys.argv[1]) if len(sys.argv) > 1 else 35.0

# Ожидаемая выручка с контейнера каждого типа при нейтральных перках и среднем качестве.
TIER_EV = [4000, 16000, 64000, 250000, 1000000]
TIER_ITEMS = [1.5, 3.0, 3.5, 2.5, 3.5]
TIER_NAMES = ["Коробка", "Ящик", "Сейф", "Грузовой", "Секретный"]
# Порог числа открытых контейнеров для каждого уровня лаборатории (уровень = индекс + 1).
LEVELS = [0, 12, 30, 70, 130, 220, 360, 560, 840, 1250, 1800, 2600, 3600, 5000, 7000]
# С какого уровня тип контейнера может выпасть.
TIER_UNLOCK = [1, 2, 4, 8, 12]
BASE_WEIGHTS = [100, 38, 14, 4.5, 1.4]
ODDS_STEP = 0.12
PRICE_SHARE = 0.6
COST_SCALE = 1.0
COST_GROWTH = 2.0
MIN_PRICE = 2500
QUALITY_MEAN = 0.2 * 0.605 + 0.4 * 0.85 + 0.3 * 1.15 + 0.08 * 1.52 + 0.02 * 1.75


def level_for(opened):
    level = 1
    for index, need in enumerate(LEVELS):
        if opened >= need:
            level = index + 1
    return level


def odds(opened, odds_level):
    level = level_for(opened)
    weights = []
    for tier in range(5):
        if level < TIER_UNLOCK[tier]:
            weights.append(0.0)
        else:
            weights.append(BASE_WEIGHTS[tier] * (1 + ODDS_STEP * odds_level) ** tier)
    total = sum(weights)
    return [w / total for w in weights]


def tier_ev(tier, perks):
    items = TIER_ITEMS[tier] + 0.06 * perks.get("bonusLoot", 0)
    quality = quality_mean(perks.get("quality", 0))
    sale = 0.05 * perks.get("sale", 0)
    collection = 0.03 * (1 + 0.25 * perks.get("collection", 0))
    base = TIER_EV[tier] / TIER_ITEMS[tier] / QUALITY_MEAN
    return items * base * (quality + sale + collection)


def quality_mean(level):
    # Преимущество: с шансом 10% × уровень берётся лучший из двух бросков.
    table = [(0.2, 0.605), (0.4, 0.85), (0.3, 1.15), (0.08, 1.52), (0.02, 1.75)]
    cdf, edges = 0.0, []
    for chance, value in table:
        cdf += chance
        edges.append((cdf, value))
    best = 0.0
    previous = 0.0
    for cumulative, value in edges:
        best += (cumulative**2 - previous**2) * value
        previous = cumulative
    chance = min(1.0, 0.1 * level)
    return QUALITY_MEAN * (1 - chance) + best * chance


def order_price(opened, perks):
    mix = odds(opened, 0)
    neutral = sum(p * (TIER_EV[t]) for t, p in enumerate(mix))
    price = max(MIN_PRICE, round(neutral * PRICE_SHARE / 50) * 50)
    return round(price * (1 - 0.04 * perks.get("discount", 0)))


# key: (уровней, родитель, уровень родителя, пороги открытых контейнеров, множитель стоимости k)
# Стоимость уровня = k × чистая прибыль с контейнера на уровне, где он открывается.
PERKS = {
    "storage": (7, None, 0, [0, 8, 20, 50, 110, 220, 420], 6),
    "orders": (4, None, 0, [6, 40, 200, 700], 10),
    "delivery": (5, "orders", 1, [15, 70, 220, 520, 1000], 9),
    "discount": (5, "delivery", 2, [60, 220, 560, 1100, 1900], 22),
    "odds": (6, None, 0, [10, 40, 130, 340, 760, 1500], 12),
    "quality": (5, "odds", 2, [40, 130, 300, 640, 1200], 22),
    "bonusLoot": (4, "quality", 2, [100, 320, 800, 1600], 30),
    "variant": (4, "bonusLoot", 1, [170, 520, 1200, 2300], 28),
    "sale": (10, None, 0, [0, 5, 18, 45, 90, 160, 270, 430, 650, 950], 5),
    "quickSell": (1, "sale", 3, [80], 8),
    "quickCollect": (1, "storage", 2, [25], 6),
    "collection": (4, "sale", 5, [250, 600, 1200, 2100], 24),
    "daily": (3, "orders", 1, [40, 300, 1000], 5),
}


def perk_costs():
    costs = {}
    for key, (levels, _, _, needs, k) in PERKS.items():
        row = []
        for index in range(levels):
            level = level_for(needs[index])
            ev = sum(p * TIER_EV[t] for t, p in enumerate(odds(needs[index], 0)))
            profit = max(1500, ev * (1 - PRICE_SHARE))
            row.append(int(round(profit * k * COST_SCALE * (COST_GROWTH ** index) / 100) * 100))
        costs[key] = row
    return costs


def main():
    print("Уровни лаборатории (порог → цена заказа, выручка, шансы типов):")
    for index, need in enumerate(LEVELS):
        mix = odds(need, 0)
        ev = sum(p * TIER_EV[t] for t, p in enumerate(mix))
        shares = " ".join(f"{p * 100:4.1f}" for p in mix)
        print(f"  L{index + 1:<2} от {need:>5}: цена {order_price(need, {}):>8,}  выручка {ev:>9,.0f}  [{shares}]")

    costs = perk_costs()
    print("\nСтоимости перков:")
    for key, row in costs.items():
        print(f"  {key:12} {row}")

    random.seed(1)
    coins, opened, perks = 2500, 0, {}
    seconds, log, last = 0.0, [], 0
    total_costs = sum(sum(row) for row in costs.values())
    spent = 0
    while opened < 9000:
        price = order_price(opened, perks)
        if coins < price:
            # Игрок без денег ждёт; симуляция считает это тупиком и добавляет минимальный доход.
            coins += 300
            seconds += SECONDS_PER_CONTAINER
            continue
        coins -= price
        mix = odds(opened, perks.get("odds", 0))
        tier = random.choices(range(5), mix)[0]
        coins += tier_ev(tier, perks)
        opened += 1
        seconds += SECONDS_PER_CONTAINER * (1 - 0.04 * perks.get("delivery", 0))
        bought = True
        while bought:
            bought = False
            options = []
            for key, (levels, parent, need, opens, _) in PERKS.items():
                level = perks.get(key, 0)
                if level >= levels or opened < opens[level]:
                    continue
                if parent and perks.get(parent, 0) < need:
                    continue
                options.append((costs[key][level], key))
            options.sort()
            if options and options[0][0] <= coins - order_price(opened, perks):
                cost, key = options[0]
                coins -= cost
                spent += cost
                perks[key] = perks.get(key, 0) + 1
                bought = True
                log.append((opened, seconds / 3600, f"{key} → {perks[key]}"))
        if opened in (10, 25, 50, 100, 250, 500, 1000, 2000, 3000, 4500):
            print(
                f"  открыто {opened:>5} · {seconds / 3600:6.1f} ч · монеты {coins:>13,.0f} · цена {order_price(opened, perks):>9,} · перков куплено {sum(perks.values())}"
            )
        if all(perks.get(k, 0) >= v[0] for k, v in PERKS.items()) and last == 0:
            last = opened
            print(f"\nВсе перки куплены: контейнер {opened}, {seconds / 3600:.1f} ч")
            break
    print(f"Сумма стоимости всех перков: {total_costs:,}")
    print("\nПервые покупки:")
    for opened_at, hours, name in log[:14]:
        print(f"  контейнер {opened_at:>4} ({hours * 60:5.1f} мин): {name}")


main()
