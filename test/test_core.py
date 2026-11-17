"""Game tests supply candidates directly: no LFSR implementation or dependency."""
from collections import Counter
from itertools import permutations
import random

import cocotb
from cocotb.triggers import Timer

PAYOUTS = [0, 5, 10, 15, 20, 30, 45, 125, 250, 4000]
DECK = [(s << 4) | r for s in range(4) for r in range(2, 15)]
EVALUATION_CYCLES = 16


def pack(cards):
    return sum(card << (6 * i) for i, card in enumerate(cards))


def hand(dut):
    bits = int(dut.cards.value)
    return [(bits >> (6 * i)) & 63 for i in range(5)]


def used(cards):
    return sum(1 << ((c >> 4) * 13 + (c & 15) - 2) for c in set(cards))


def reference(cards):
    ranks = [c & 15 for c in cards]
    if len(set(cards)) != 5 or any(r < 2 or r > 14 for r in ranks):
        return 0
    counts = Counter(ranks)
    groups = sorted(counts.values(), reverse=True)
    flush = len({c >> 4 for c in cards}) == 1
    straight = len(counts) == 5 and (
        max(ranks) - min(ranks) == 4 or set(ranks) == {14, 2, 3, 4, 5}
    )
    if straight and flush:
        return 9 if min(ranks) == 10 else 8
    if groups == [4, 1]:
        return 7
    if groups == [3, 2]:
        return 6
    if flush:
        return 5
    if straight:
        return 4
    if groups == [3, 1, 1]:
        return 3
    if groups == [2, 2, 1]:
        return 2
    if any(n == 2 and r >= 11 for r, n in counts.items()):
        return 1
    return 0


async def tick(dut, count=1):
    for _ in range(count):
        dut.clk.value = 0
        await Timer(20, unit="ns")
        dut.clk.value = 1
        await Timer(20, unit="ns")
        dut.clk.value = 0


async def reset(dut):
    dut.deal_draw_pulse.value = 0
    dut.hold_mask.value = 0
    dut.prng_ready.value = 0
    dut.rst_n.value = 0
    await Timer(1, unit="ns")
    assert int(dut.balance.value) == 100
    assert int(dut.cards.value) == 0
    assert int(dut.dealt_mask.value) == 0
    assert int(dut.state.value) == 0
    dut.rst_n.value = 1
    await tick(dut)


async def press_deal_draw(dut, holds=0):
    dut.hold_mask.value = holds
    dut.deal_draw_pulse.value = 1
    await tick(dut)
    dut.deal_draw_pulse.value = 0


async def wait_state(dut, state):
    for _ in range(64):
        if int(dut.state.value) == state:
            return
        await tick(dut)
    assert False, f"Timed out waiting for state {state}: {dut.state.value}"


async def offer(dut, card):
    dut.prng_ready.value = 0
    for _ in range(8):
        if int(dut.dealer_ready.value):
            break
        await tick(dut)
    else:
        assert False, "Dealer did not request a candidate"
    dut.candidate.value = card
    dut.prng_ready.value = 1
    await tick(dut)
    dut.prng_ready.value = 0


async def deal(dut, cards, holds=0):
    await press_deal_draw(dut, holds)
    for card in cards:
        await offer(dut, card)
    await wait_state(dut, 2)
    assert hand(dut) == cards


@cocotb.test()
async def basic_deal_draw_round(dut):
    """Reset, deal five cards, replace two, and credit two pair exactly once."""
    dut = dut.core_unit
    await reset(dut)
    assert int(dut.can_deal.value) == 1
    initial = [2, 0x15, 0x29, 0x3B, 13]
    await deal(dut, initial)
    assert int(dut.balance.value) == 95
    assert int(dut.can_deal.value) == 0

    await press_deal_draw(dut, 0b10101)  # Keep cards 1, 3, and 5.
    await offer(dut, 0x12)  # Pair of twos.
    await offer(dut, 0x1D)  # Pair of kings.
    await wait_state(dut, 5)
    assert hand(dut) == [2, 0x12, 0x29, 0x1D, 13]
    assert int(dut.result_category.value) == 2
    assert int(dut.result_payout.value) == 10
    assert int(dut.balance.value) == 105
    assert int(dut.can_deal.value) == 1
    await tick(dut, 5)
    assert int(dut.balance.value) == 105


@cocotb.test()
async def hold_switches_do_not_trigger_deal_or_draw(dut):
    """Changing hold levels only selects cards; Deal/Draw requires its pulse."""
    dut = dut.core_unit
    await reset(dut)
    for holds in [1, 0b10101, 31, 0]:
        dut.hold_mask.value = holds
        await tick(dut, 2)
        assert int(dut.state.value) == 0
        assert int(dut.balance.value) == 100
        assert int(dut.cards.value) == 0
        assert int(dut.dealer_ready.value) == 0

    # Hold switches must not prevent any of the five initial cards being dealt.
    initial = [2, 0x15, 0x29, 0x3B, 13]
    await deal(dut, initial, holds=31)
    for holds in [31, 0b10101, 0, 0b01010]:
        dut.hold_mask.value = holds
        await tick(dut, 2)
        assert int(dut.state.value) == 2
        assert int(dut.held_cards.value) == holds
        assert hand(dut) == initial
        assert int(dut.balance.value) == 95
        assert int(dut.dealer_ready.value) == 0

    # A separate Deal/Draw pulse starts the draw. With all cards held, no
    # candidate is required, and subsequent switch changes cannot alter it.
    await press_deal_draw(dut, 31)
    dut.hold_mask.value = 0
    await wait_state(dut, 5)
    assert hand(dut) == initial
    assert int(dut.held_cards.value) == 31
    assert int(dut.balance.value) == 95
    dut.hold_mask.value = 0b01010
    await tick(dut, 2)
    assert int(dut.state.value) == 5
    assert int(dut.held_cards.value) == 31
    assert int(dut.balance.value) == 95


async def reset_evaluator(dut):
    dut.clk.value = 0
    dut.start.value = 0
    dut.rst_n.value = 0
    await Timer(1, unit="ns")
    assert int(dut.done.value) == 0
    assert int(dut.category.value) == 0
    assert int(dut.payout.value) == 0
    dut.rst_n.value = 1


async def evaluate(dut, cards, category):
    previous = int(dut.category.value)
    dut.cards.value = pack(cards)
    dut.start.value = 1
    await tick(dut)
    dut.start.value = 0
    assert int(dut.done.value) == 0
    for cycle in range(1, EVALUATION_CYCLES + 1):
        await tick(dut)
        assert int(dut.done.value) == (cycle == EVALUATION_CYCLES), (cards, cycle)
        if cycle < EVALUATION_CYCLES:
            assert int(dut.category.value) == previous
    assert int(dut.category.value) == category, cards
    assert int(dut.payout.value) == PAYOUTS[category], cards


@cocotb.test()
async def evaluator_categories_and_reference(dut):
    dut = dut.evaluator_unit
    await reset_evaluator(dut)
    # Every category, low pair, both ace straights, invalid wrap and duplicates.
    cases = [
        ([2, 0x15, 0x29, 0x3B, 13], 0),
        ([11, 0x1B, 0x22, 0x35, 9], 1),
        ([10, 0x1A, 0x22, 0x35, 9], 0),
        ([2, 0x12, 0x2D, 0x3D, 9], 2),
        ([7, 0x17, 0x27, 0x3B, 14], 3),
        ([10, 0x1B, 0x2C, 0x3D, 14], 4),
        ([14, 0x12, 0x23, 0x34, 5], 4),
        ([2, 5, 8, 11, 14], 5),
        ([7, 0x17, 0x27, 0x3E, 14], 6),
        ([7, 0x17, 0x27, 0x37, 14], 7),
        ([4, 5, 6, 7, 8], 8),
        ([14, 2, 3, 4, 5], 8),
        ([10, 11, 12, 13, 14], 9),
        ([12, 0x1D, 0x2E, 0x32, 3], 0),
        ([2, 2, 3, 4, 5], 0),
        ([0, 3, 4, 5, 6], 0),
        ([15, 3, 4, 5, 6], 0),
        ([1, 3, 4, 5, 6], 0),
        ([10, 11, 12, 13, 13], 0),
        ([7, 0x17, 0x27, 0x37, 7], 0),
    ]
    # Every ordinary straight window, both mixed suits and each flush suit.
    for low in range(2, 11):
        ranks = list(range(low, low + 5))
        cases.append(([r | ((i % 4) << 4) for i, r in enumerate(ranks)], 4))
        for suit in range(4):
            cases.append(([r | (suit << 4) for r in ranks], 9 if low == 10 else 8))
    for cards, category in cases:
        for ordered in permutations(cards):
            await evaluate(dut, ordered, category)
    rng = random.Random(298)
    for _ in range(3000):
        cards = rng.sample(DECK, 5)
        await evaluate(dut, cards, reference(cards))
    # Include all six-bit encodings, invalid ranks, and repeated cards.
    for _ in range(1000):
        cards = [rng.randrange(64) for _ in range(5)]
        await evaluate(dut, cards, reference(cards))


@cocotb.test()
async def evaluator_handshake_and_reset(dut):
    dut = dut.evaluator_unit
    await reset_evaluator(dut)
    royal = [10, 11, 12, 13, 14]
    await evaluate(dut, royal, 9)
    # done is a pulse, and changing cards while idle cannot change the result.
    dut.cards.value = 0
    await tick(dut, 3)
    assert int(dut.done.value) == 0
    assert int(dut.category.value) == 9
    assert int(dut.payout.value) == 4000

    # A start pulse in any active phase must not restart or queue evaluation.
    dut.cards.value = pack(royal)
    dut.start.value = 1
    await tick(dut)
    for cycle in range(1, EVALUATION_CYCLES + 1):
        dut.start.value = int(cycle in (1, 6, 15, 16))
        await tick(dut)
        assert int(dut.done.value) == (cycle == EVALUATION_CYCLES)
    dut.start.value = 0
    await tick(dut, EVALUATION_CYCLES + 2)
    assert int(dut.done.value) == 0
    assert int(dut.category.value) == 9

    # Asynchronous reset cancels evaluation at every point, including done.
    for elapsed in range(EVALUATION_CYCLES + 1):
        dut.start.value = 1
        await tick(dut)
        dut.start.value = 0
        await tick(dut, elapsed)
        await reset_evaluator(dut)
        await tick(dut, EVALUATION_CYCLES + 2)
        assert int(dut.done.value) == 0
        assert int(dut.category.value) == 0
        await evaluate(dut, royal, 9)


@cocotb.test()
async def core_waits_for_evaluation(dut):
    dut = dut.core_unit
    royal = [10, 11, 12, 13, 14]
    await reset(dut)
    await deal(dut, royal)
    await press_deal_draw(dut, 31)
    await wait_state(dut, 4)
    # Inputs while evaluating cannot alter the hand, debit, or credit early.
    dut.deal_draw_pulse.value = 1
    dut.hold_mask.value = 0
    dut.prng_ready.value = 1
    dut.candidate.value = 2
    for _ in range(EVALUATION_CYCLES):
        assert int(dut.state.value) == 4
        assert int(dut.balance.value) == 95
        assert int(dut.result_category.value) == 0
        assert int(dut.result_payout.value) == 0
        assert int(dut.can_deal.value) == 0
        assert int(dut.dealer_ready.value) == 0
        assert int(dut.held_cards.value) == 31
        assert hand(dut) == royal
        await tick(dut)
    dut.deal_draw_pulse.value = 0
    await tick(dut)
    assert int(dut.state.value) == 5
    assert int(dut.result_category.value) == 9
    assert int(dut.result_payout.value) == 4000
    assert int(dut.balance.value) == 4095
    await tick(dut, EVALUATION_CYCLES + 2)
    assert int(dut.balance.value) == 4095

    # Reset during evaluation must not allow a delayed award into a new round.
    for elapsed in (0, 5, 15, 16):
        await reset(dut)
        await deal(dut, royal)
        await press_deal_draw(dut, 31)
        await wait_state(dut, 4)
        await tick(dut, elapsed)
        await reset(dut)
        await tick(dut, EVALUATION_CYCLES + 2)
        assert int(dut.state.value) == 0
        assert int(dut.balance.value) == 100
        assert int(dut.result_payout.value) == 0
    await deal(dut, royal)
    await press_deal_draw(dut, 31)
    await wait_state(dut, 5)
    assert int(dut.balance.value) == 4095


@cocotb.test()
async def rejection_holds_and_accounting(dut):
    dut = dut.core_unit
    await reset(dut)
    await press_deal_draw(dut)
    assert int(dut.balance.value) == 95
    await tick(dut, 4)  # No valid candidate: must stall.
    assert int(dut.cards.value) == 0
    for invalid in [0, 1, 15, 0x30, 0x31, 0x3F]:
        await offer(dut, invalid)
        assert int(dut.dealt_mask.value) == 0
    initial = [2, 0x15, 0x29, 0x3B, 13]
    await offer(dut, initial[0])
    await press_deal_draw(dut)  # Busy actions do not restart or debit again.
    await offer(dut, initial[0])
    assert int(dut.dealt_mask.value) == used(initial[:1])
    for card in initial[1:]:
        await offer(dut, card)
    await wait_state(dut, 2)
    assert int(dut.balance.value) == 95
    await press_deal_draw(dut, 0b10101)
    dut.hold_mask.value = 0  # Snapshot must survive subsequent switch changes.
    await offer(dut, initial[1])  # Discarded cards cannot return.
    await offer(dut, 0x12)
    await offer(dut, initial[3])
    await offer(dut, 0x1D)
    await wait_state(dut, 5)
    assert hand(dut) == [2, 0x12, 0x29, 0x1D, 13]
    assert int(dut.held_cards.value) == 0b10101
    assert int(dut.dealt_mask.value) == used(initial + [0x12, 0x1D])
    assert int(dut.result_category.value) == 2
    assert int(dut.result_payout.value) == 10
    assert int(dut.balance.value) == 105
    await tick(dut, 10)
    assert int(dut.balance.value) == 105  # Award exactly once.
    royal = [10, 11, 12, 13, 14]
    await deal(dut, royal)
    assert int(dut.dealt_mask.value) == used(royal)
    await press_deal_draw(dut, 31)
    await wait_state(dut, 5)  # Hold all needs no RNG candidate.
    assert int(dut.balance.value) == 4100
    assert int(dut.result_category.value) == 9


@cocotb.test()
async def all_hold_masks_and_random_rounds(dut):
    dut = dut.core_unit
    rng = random.Random(52)
    await reset(dut)
    expected_balance = 100
    for holds in range(32):
        # Reset each scenario to avoid bankruptcy hiding a hold-mask case.
        await reset(dut)
        expected_balance = 95
        selected = rng.sample(DECK, 10)
        initial, replacements = selected[:5], iter(selected[5:])
        await deal(dut, initial)
        await press_deal_draw(dut, holds)
        expected = initial[:]
        consumed = initial[:]
        for i in range(5):
            if not (holds >> i) & 1:
                replacement = next(replacements)
                await tick(dut, rng.randrange(3))
                await offer(dut, replacement)
                expected[i] = replacement
                consumed.append(replacement)
        await wait_state(dut, 5)
        category = reference(expected)
        assert hand(dut) == expected
        assert int(dut.dealt_mask.value) == used(consumed)
        assert int(dut.result_category.value) == category
        assert int(dut.balance.value) == expected_balance + PAYOUTS[category]


@cocotb.test()
async def bankruptcy_overflow_and_reset(dut):
    dut = dut.core_unit
    await reset(dut)
    losing = [2, 0x15, 0x29, 0x3B, 13]
    for round_number in range(20):
        await deal(dut, losing)
        await press_deal_draw(dut, 31)
        await wait_state(dut, 5)
        assert int(dut.balance.value) == 100 - 5 * (round_number + 1)
    assert int(dut.can_deal.value) == 0
    await press_deal_draw(dut)
    assert int(dut.state.value) == 5
    assert int(dut.balance.value) == 0
    await reset(dut)
    royal = [10, 11, 12, 13, 14]
    for _ in range(18):
        await deal(dut, royal)
        await press_deal_draw(dut, 31)
        await wait_state(dut, 5)
    assert int(dut.balance.value) == 65535
    # Asynchronous reset while filling both an initial hand and a draw.
    await press_deal_draw(dut)
    await offer(dut, 2)
    await reset(dut)
    await deal(dut, losing)
    await press_deal_draw(dut)
    await offer(dut, 3)
    await reset(dut)
    await deal(dut, royal)
    await press_deal_draw(dut, 31)
    await wait_state(dut, 5)
    assert int(dut.balance.value) == 4095
