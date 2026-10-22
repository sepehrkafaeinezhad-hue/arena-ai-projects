#!/usr/bin/env python3
"""
Reference tests for the algorithms implemented in GoldSweepEA.mq5.

These tests mirror the formulas line-by-line so the arithmetic and edge cases
can be executed on any machine (no MetaTrader required). They are NOT a
backtest and do not test the MQL5 runtime.

Run: python3 verify_algorithms.py
"""
from dataclasses import dataclass


# ---------------------------------------------------------------- helpers
def floor_to_step(lots: float, step: float, vol_min: float, vol_max: float, digits: int = 8) -> float:
    if step <= 0:
        return 0.0
    steps = int((lots + 1e-9) // step)
    result = round(steps * step, digits)
    if result > vol_max:
        steps = int((vol_max + 1e-9) // step)
        result = round(steps * step, digits)
    return max(result, 0.0)


def round_to_tick(price: float, tick: float, digits: int, mode: int = 0) -> float:
    """mode 0=nearest, 1=down, 2=up (same as EA RoundToTick)."""
    if tick <= 0:
        return round(price, digits)
    steps = price / tick
    if mode == 1:
        val = int((steps + 1e-9) // 1) * tick
    elif mode == 2:
        import math
        val = math.ceil(steps - 1e-9) * tick
    else:
        val = round(steps) * tick
    return round(val, digits)


def build_levels(direction: str, entry: float, sweep: float, atr: float, atr_mult: float,
                 min_sl_points: int, max_sl_points: int, rr: float, point: float,
                 tick: float, digits: int):
    """Mirror of BuildLevels(); returns (sl, tp, error)."""
    raw = entry - (sweep - atr_mult * atr) if direction == "BUY" else (sweep + atr_mult * atr) - entry
    if raw <= 0:
        return 0.0, 0.0, "invalid geometry"
    raw = max(raw, min_sl_points * point)
    if max_sl_points > 0 and raw > max_sl_points * point + 1e-9:
        return 0.0, 0.0, "sl too wide"
    if direction == "BUY":
        sl = round_to_tick(entry - raw, tick, digits, 1)
        tp = round_to_tick(entry + rr * raw, tick, digits, 2) if rr > 0 else 0.0
    else:
        sl = round_to_tick(entry + raw, tick, digits, 2)
        tp = round_to_tick(entry - rr * raw, tick, digits, 1) if rr > 0 else 0.0
    if abs(entry - sl) < point:
        return 0.0, 0.0, "collapsed"
    return sl, tp, ""


def calc_lots_percent(target_risk: float, per_lot_risk: float, vol_min: float, vol_step: float,
                      vol_max: float, max_risk_mult: float):
    """Mirror of CalcLots() percent mode (returns lots, actual risk, error)."""
    if per_lot_risk <= 0 or target_risk <= 0:
        return 0.0, 0.0, "bad input"
    raw = target_risk / per_lot_risk
    lots = floor_to_step(raw, vol_step, vol_min, vol_max)
    if lots < vol_min:
        min_risk = per_lot_risk * vol_min
        if max_risk_mult > 0 and min_risk <= target_risk * max_risk_mult + 1e-9:
            lots = vol_min
        else:
            return 0.0, 0.0, "min lot risks more than cap"
    actual = per_lot_risk * lots
    if max_risk_mult > 0 and actual > target_risk * max_risk_mult * (1 + 1e-9):
        return 0.0, 0.0, "actual risk above cap"
    return lots, actual, ""


def validate_stops(direction: str, sl: float, tp: float, bid: float, ask: float,
                   point: float, stops_level: int, freeze_level: int):
    """Mirror of ValidateStops(): side-aware distances."""
    min_dist = max(stops_level, freeze_level) * point
    if min_dist < point:
        min_dist = point
    if direction == "BUY":
        if sl > 0 and (bid - sl) < min_dist:
            return False, "SL too close"
        if tp > 0 and (tp - bid) < min_dist:
            return False, "TP too close"
    else:
        if sl > 0 and (sl - ask) < min_dist:
            return False, "SL too close"
        if tp > 0 and (ask - tp) < min_dist:
            return False, "TP too close"
    return True, ""


def in_session(minute_of_day: int, start_h: int, start_m: int, end_h: int, end_m: int, shift_h: int = 0) -> bool:
    def norm(m):
        return m % 1440
    start = norm(start_h * 60 + start_m + shift_h * 60)
    end = norm(end_h * 60 + end_m + shift_h * 60)
    if start == end:
        return True
    if start < end:
        return start <= minute_of_day < end
    return minute_of_day >= start or minute_of_day < end


def account_daily_loss(start_balance: float, equity: float, net_balance_flow: float) -> float:
    """Mirror of the account-scope loss: (equity - start) - external flows."""
    pnl = (equity - start_balance) - net_balance_flow
    return max(0.0, -pnl)


def daily_baseline(balance_now: float, deals) -> float:
    """deals: list of dicts {type: BUY/SELL/BALANCE/..., pnl: float}.
    balance_now = start + sum(all deal pnl) -> start."""
    return balance_now - sum(d["pnl"] for d in deals)


@dataclass
class Bar:
    o: float
    h: float
    l: float
    c: float


def detect_sweep(bars, lookback, atr, point, min_pen_atr, reclaim_atr, reversal_close, trend_dir):
    """bars[0] = last closed bar, bars[1..] = older (same as EA)."""
    sb = bars[0]
    support = min(b.l for b in bars[1:lookback + 1])
    resistance = max(b.h for b in bars[1:lookback + 1])
    pen = min_pen_atr * atr
    buf = reclaim_atr * atr
    bull = (support - sb.l) > pen and sb.c > support + buf
    bear = (sb.h - resistance) > pen and sb.c < resistance - buf
    rev_buy = (not reversal_close) or sb.c > sb.o
    rev_sell = (not reversal_close) or sb.c < sb.o
    if bull and not bear and rev_buy and trend_dir >= 0:
        return "BUY", support, resistance
    if bear and not bull and rev_sell and trend_dir <= 0:
        return "SELL", support, resistance
    return "NONE", support, resistance


# ---------------------------------------------------------------- tests
def main() -> int:
    checks = 0

    # 1) volume floor on different broker steps
    assert floor_to_step(0.0189, 0.01, 0.01, 100) == 0.01
    assert floor_to_step(0.007, 0.01, 0.01, 100) == 0.0
    assert floor_to_step(0.0189, 0.001, 0.01, 100) == 0.018
    assert floor_to_step(123.0, 0.1, 0.1, 100) == 100.0
    checks += 4

    # 2) tick rounding directions (SL away from price, TP away from price)
    assert round_to_tick(2000.123, 0.01, 2, 1) == 2000.12
    assert round_to_tick(2000.121, 0.01, 2, 2) == 2000.13
    assert round_to_tick(2000.125, 0.01, 2, 0) in (2000.12, 2000.13)
    checks += 3

    # 3) SL geometry: min clamp / max reject / RR
    sl, tp, err = build_levels("BUY", 2400.00, 2399.50, 2.00, 1.0, 120, 900, 2.0, 0.01, 0.01, 2)
    assert err == "" and sl < 2400.00
    # raw distance = entry - (sweep - ATR*mult) = 2400 - (2399.50 - 2.00) = 2.50
    assert abs((2400.00 - sl) - 2.50) < 1e-9, (sl, (2400.00 - sl))
    assert abs((tp - 2400.00) - 5.00) < 1e-9, tp
    sl2, tp2, err2 = build_levels("SELL", 2400.00, 2400.50, 2.00, 1.0, 120, 900, 2.0, 0.01, 0.01, 2)
    assert err2 == "" and sl2 > 2400.00 and tp2 < 2400.00
    # min stop distance enforced (0.10 move -> 120 points = 1.20)
    sl3, tp3, err3 = build_levels("BUY", 2400.00, 2399.95, 0.10, 1.0, 120, 900, 2.0, 0.01, 0.01, 2)
    assert err3 == "" and abs((2400.00 - sl3) - 1.20) < 1e-9, (sl3, err3)
    # too wide -> rejected
    _, _, err4 = build_levels("BUY", 2410.00, 2399.00, 2.00, 1.0, 120, 900, 2.0, 0.01, 0.01, 2)
    assert err4 == "sl too wide"
    checks += 10

    # 4) risk sizing (0.5% of 10k = $50; gold 1 lot risks $120 for 120 points)
    lots, risk, err = calc_lots_percent(50.0, 120.0, 0.01, 0.01, 100, 1.0)
    assert err == "" and lots == 0.41 and abs(risk - 49.2) < 1e-9, (lots, risk, err)
    # target 0.50 < min-lot risk 1.20 and multiplier 1.0 -> trade must be rejected
    lots_min, risk_min, err_min = calc_lots_percent(0.50, 120.0, 0.01, 0.01, 100, 1.0)
    assert err_min != "" and lots_min == 0.0
    # target 0.50 with multiplier 2.5 (>1.20) -> min lot allowed
    lots_min_ok, risk_min_ok, err_min_ok = calc_lots_percent(0.50, 120.0, 0.01, 0.01, 100, 2.5)
    assert err_min_ok == "" and lots_min_ok == 0.01 and risk_min_ok == 1.20
    # min lot override blocked when it would exceed target x multiplier
    lots_cap, _, err_cap = calc_lots_percent(0.50, 120.0, 0.01, 0.01, 100, 0.0)
    assert err_cap != "" and lots_cap == 0.0
    # capped override allowed exactly at multiplier 2.5
    lots_ok, risk_ok, err_ok = calc_lots_percent(0.50, 120.0, 0.01, 0.01, 100, 2.5)
    assert err_ok == "" and lots_ok == 0.01 and risk_ok == 1.20
    checks += 10

    # 5) side-aware stop validation: SL of a BUY is measured against BID
    ok, _ = validate_stops("BUY", 2399.00, 2401.00, bid=2400.00, ask=2400.30, point=0.01,
                           stops_level=50, freeze_level=0)
    assert ok
    bad, reason = validate_stops("BUY", 2399.80, 2401.00, bid=2400.00, ask=2400.30, point=0.01,
                                 stops_level=50, freeze_level=0)
    assert not bad and "SL" in reason
    # SELL is measured against ASK: 2400.70 is only 40 points from ask=2400.30
    bad_sell, reason_sell = validate_stops("SELL", 2400.70, 2399.00, bid=2400.00, ask=2400.30,
                                           point=0.01, stops_level=50, freeze_level=0)
    assert not bad_sell and "SL" in reason_sell
    checks += 4

    # 6) session wrap and DST shift
    assert in_session(600, 9, 0, 22, 0)                 # 10:00 inside
    assert not in_session(120, 9, 0, 22, 0)             # 02:00 outside
    assert in_session(1380, 22, 0, 2, 0)                # 23:00 inside overnight
    assert not in_session(600, 22, 0, 2, 0)             # 10:00 outside overnight
    assert in_session(600, 9, 0, 22, 0, shift_h=-1)     # shift moves window
    assert not in_session(480, 9, 0, 22, 0, shift_h=1)  # 08:00 now outside
    checks += 6

    # 7) daily baseline is exact with deposits / withdrawals / costs
    deals = [
        {"type": "BUY", "pnl": 25.0},
        {"type": "SELL", "pnl": -10.0},
        {"type": "BUY", "pnl": -1.5},     # commission
        {"type": "BALANCE", "pnl": 500.0},  # deposit
        {"type": "BALANCE", "pnl": -200.0}, # withdrawal
    ]
    balance_now = 10000.0 - 200.0 + 25.0 - 10.0 - 1.5 + 500.0
    assert abs(daily_baseline(balance_now, deals) - 10000.0) < 1e-9
    # loss percent after the deposit/withdrawal and 13.5 net loss
    start = daily_baseline(balance_now, deals)
    loss_pct = 13.5 / start * 100
    assert 0.13 < loss_pct < 0.14
    # external cash flows must not create a false daily loss
    assert account_daily_loss(10000, 9900, 0.0) == 100.0
    assert account_daily_loss(10000, 9500, -500.0) == 0.0     # withdrawal only
    assert account_daily_loss(10000, 10500, 500.0) == 0.0     # deposit only
    assert account_daily_loss(10000, 10400, 500.0) == 100.0   # deposit + 100 loss
    assert account_daily_loss(10000, 10300, 500.0) == 200.0   # deposit + 200 loss
    checks += 8

    # 8) sweep detection scenarios
    bars_bull = [
        Bar(100.0, 100.4, 99.0, 100.2),   # sweeps 99.5 support low, closes back above
        Bar(100.5, 100.8, 99.5, 100.4),
        Bar(100.4, 100.9, 99.8, 100.6),
        Bar(100.6, 101.0, 100.0, 100.8),
    ]
    sig, sup, res = detect_sweep(bars_bull, 3, 0.5, 0.01, 0.10, 0.0, True, 1)
    assert sig == "BUY" and sup == 99.5, (sig, sup)
    sig_up, _, _ = detect_sweep(bars_bull, 3, 0.5, 0.01, 0.10, 0.0, True, -1)
    assert sig_up == "NONE"           # trend filter blocks the long
    bars_bear = [
        Bar(100.5, 101.2, 99.9, 100.1),   # bearish close after sweeping 101.0
        Bar(100.5, 100.8, 99.5, 100.4),
        Bar(100.4, 100.9, 99.8, 100.6),
        Bar(100.6, 101.0, 100.0, 100.8),
    ]
    sig_bear, _, res_bear = detect_sweep(bars_bear, 3, 0.5, 0.01, 0.10, 0.0, True, -1)
    assert sig_bear == "SELL" and res_bear == 101.0, (sig_bear, res_bear)
    # no sweep: bar stays inside the range
    bars_none = [
        Bar(100.0, 100.6, 99.9, 100.3),
        Bar(100.5, 100.8, 99.5, 100.4),
        Bar(100.4, 100.9, 99.8, 100.6),
        Bar(100.6, 101.0, 100.0, 100.8),
    ]
    sig_none, _, _ = detect_sweep(bars_none, 3, 0.5, 0.01, 0.10, 0.0, True, 0)
    assert sig_none == "NONE"
    checks += 4

    print(f"ALGORITHM TESTS: PASS ({checks} assertions)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
