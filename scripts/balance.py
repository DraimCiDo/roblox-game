#!/usr/bin/env python3
"""Симуляция темпа прогресса. Параметры должны совпадать с Economy.luau и Catalog.luau.

Запуск: python3 scripts/balance.py [секунд на контейнер]
Печатает: цену заказа и выручку по уровням, стоимости навыков, ход «жадного» игрока, который покупает
самый дешёвый доступный навык, и время до полного дерева. Структура дерева — scripts/perks_spec.py.
Нужен только для настройки чисел, не для проверки правил игры.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from perks_spec import EFFECTS, PERKS  # noqa: E402

SECONDS_PER_CONTAINER = float(sys.argv[1]) if len(sys.argv) > 1 else 35.0

# Ожидаемая выручка с контейнера каждого типа при нейтральных навыках и среднем качестве.
TIER_EV = [4000, 16000, 64000, 250000, 1000000]
TIER_ITEMS = [1.5, 3.0, 3.5, 2.5, 3.5]
# Порог числа открытых контейнеров для каждого уровня лаборатории (уровень = индекс + 1).
LEVELS = [0, 12, 30, 70, 130, 220, 360, 560, 840, 1250, 1800, 2600, 3600, 5000, 7000]
# С какого уровня тип контейнера может выпасть.
TIER_UNLOCK = [1, 2, 4, 8, 12]
BASE_WEIGHTS = [100, 38, 14, 4.5, 1.4]
TIER_LUCK = [None, "crateLuck", "safeLuck", "cargoLuck", "secretLuck"]
MASTERY = ["boxMaster", "crateMaster", "safeMaster", "cargoMaster", "secretMaster"]
PRICE_SHARE = 0.6
COST_GROWTH = 2.0
QUALITY_MEAN = 0.2 * 0.605 + 0.4 * 0.85 + 0.3 * 1.15 + 0.08 * 1.52 + 0.02 * 1.75


def level_for(opened):
    level = 1
    for index, need in enumerate(LEVELS):
        if opened >= need:
            level = index + 1
    return level


def odds(opened, perks):
    level = level_for(opened)
    weights = []
    for tier in range(5):
        if level < TIER_UNLOCK[tier]:
            weights.append(0.0)
            continue
        weight = BASE_WEIGHTS[tier] * (1 + EFFECTS["OddsStep"] * perks.get("odds", 0)) ** tier
        luck = TIER_LUCK[tier]
        if luck:
            weight *= 1 + EFFECTS["TierLuckStep"] * perks.get(luck, 0)
        weights.append(weight)
    total = sum(weights)
    return [w / total for w in weights]


def quality_mean(level):
    # С шансом 10% × уровень берётся лучший из двух бросков.
    table = [(0.2, 0.605), (0.4, 0.85), (0.3, 1.15), (0.08, 1.52), (0.02, 1.75)]
    cdf, edges = 0.0, []
    for chance, value in table:
        cdf += chance
        edges.append((cdf, value))
    best, previous = 0.0, 0.0
    for cumulative, value in edges:
        best += (cumulative**2 - previous**2) * value
        previous = cumulative
    chance = min(1.0, EFFECTS["QualityStep"] * level)
    return QUALITY_MEAN * (1 - chance) + best * chance


def tier_ev(tier, perks):
    items = TIER_ITEMS[tier] + EFFECTS["LootStep"] * perks.get("bonusLoot", 0)
    quality = quality_mean(perks.get("quality", 0))
    quality += EFFECTS["PerfectStep"] * perks.get("perfect", 0) * 0.8
    sale = EFFECTS["SaleStep"] * perks.get("sale", 0)
    sale += EFFECTS["HaggleStep"] * perks.get("haggle", 0) * 0.1
    sale += EFFECTS["JunkStep"] * perks.get("junk", 0) * 0.55
    sale += EFFECTS["MasteryStep"] * perks.get(MASTERY[tier], 0)
    collection = 0.03 * (1 + EFFECTS["CollectionStep"] * perks.get("collection", 0))
    sale *= 1 + EFFECTS["JackpotStep"] * perks.get("jackpot", 0)
    base = TIER_EV[tier] / TIER_ITEMS[tier] / QUALITY_MEAN
    return items * base * (quality + sale + collection)


def order_price(opened, perks):
    mix = odds(opened, {})
    neutral = sum(p * TIER_EV[t] for t, p in enumerate(mix))
    price = max(2500, round(neutral * PRICE_SHARE / 50) * 50)
    price = round(price * (1 - EFFECTS["DiscountStep"] * perks.get("discount", 0)))
    return round(price * (1 - EFFECTS["CashbackStep"] * perks.get("cashback", 0)))


def nice(value):
    if value < 20000:
        return int(round(value / 100) * 100)
    digits = int(math.floor(math.log10(value)))
    step = 10 ** (digits - 1)
    return int(round(value / step) * step)


def perk_costs():
    """Стоимость уровня = прибыль с контейнера на уровне открытия × множитель навыка × рост^(уровень−1)."""
    costs = {}
    for spec in PERKS:
        row = []
        for index, need in enumerate(spec["opened"]):
            ev = sum(p * TIER_EV[t] for t, p in enumerate(odds(need, {})))
            profit = max(1500, ev * (1 - PRICE_SHARE))
            row.append(nice(profit * spec["k"] * (COST_GROWTH**index)))
        costs[spec["key"]] = row
    return costs


def available(spec, perks, opened):
    level = perks.get(spec["key"], 0)
    if level >= len(spec["opened"]) or opened < spec["opened"][level]:
        return False
    if spec["parent"] and perks.get(spec["parent"], 0) < spec["req"]:
        return False
    return all(perks.get(key, 0) >= need for key, need in spec["needs"])


def main():
    print("Уровни лаборатории (порог → цена заказа, выручка, шансы типов):")
    for index, need in enumerate(LEVELS):
        mix = odds(need, {})
        ev = sum(p * TIER_EV[t] for t, p in enumerate(mix))
        shares = " ".join(f"{p * 100:4.1f}" for p in mix)
        print(f"  L{index + 1:<2} от {need:>5}: цена {order_price(need, {}):>8,}  выручка {ev:>9,.0f}  [{shares}]")

    costs = perk_costs()
    levels_total = sum(len(spec["opened"]) for spec in PERKS)
    total = sum(sum(row) for row in costs.values())
    print(f"\nНавыков: {len(PERKS)}, уровней: {levels_total}, сумма стоимости: {total:,}")
    for spec in PERKS:
        print(f"  {spec['key']:16} {costs[spec['key']]}")

    random.seed(1)
    coins, opened, perks = 2500, 0, {}
    seconds, log = 0.0, []
    print()
    while opened < 14000:
        price = order_price(opened, perks)
        if coins < price:
            coins += 300  # игрок без денег: в игре от тупика защищает правило покупки навыка
            seconds += SECONDS_PER_CONTAINER
            continue
        coins -= price
        tier = random.choices(range(5), odds(opened, perks))[0]
        coins += tier_ev(tier, perks)
        opened += 1
        seconds += SECONDS_PER_CONTAINER * (1 - EFFECTS["DeliveryStep"] * perks.get("delivery", 0))
        bought = True
        while bought:
            bought = False
            options = []
            for spec in PERKS:
                if available(spec, perks, opened):
                    level = perks.get(spec["key"], 0)
                    cost = costs[spec["key"]][level] * (1 - EFFECTS["GrantStep"] * perks.get("grant", 0))
                    options.append((cost, spec["key"]))
            options.sort()
            if options and options[0][0] <= coins - order_price(opened, perks):
                cost, key = options[0]
                coins -= cost
                perks[key] = perks.get(key, 0) + 1
                bought = True
                log.append((opened, seconds / 3600, f"{key} → {perks[key]}"))
        if opened in (10, 25, 50, 100, 250, 500, 1000, 2000, 4000, 6000, 8000, 10000):
            print(
                f"  открыто {opened:>5} · {seconds / 3600:6.1f} ч · монеты {coins:>14,.0f} · цена {order_price(opened, perks):>9,} · уровней навыков {sum(perks.values())}/{levels_total}"
            )
        if all(perks.get(spec["key"], 0) >= len(spec["opened"]) for spec in PERKS):
            print(f"\nВсе навыки куплены: контейнер {opened}, {seconds / 3600:.1f} ч")
            break
    print("\nПервые покупки:")
    for opened_at, hours, name in log[:18]:
        print(f"  контейнер {opened_at:>4} ({hours * 60:5.1f} мин): {name}")


if __name__ == "__main__":
    main()
