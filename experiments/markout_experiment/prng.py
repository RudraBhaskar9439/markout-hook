"""A tiny version-stable PRNG used instead of Python's implementation PRNG."""

from __future__ import annotations


class SplitMix64:
    """Deterministic 64-bit generator with an explicitly frozen algorithm."""

    _MASK = (1 << 64) - 1
    _GAMMA = 0x9E3779B97F4A7C15

    def __init__(self, seed: int) -> None:
        if seed < 0 or seed > self._MASK:
            raise ValueError("seed must fit in uint64")
        self._state = seed

    def next_u64(self) -> int:
        self._state = (self._state + self._GAMMA) & self._MASK
        value = self._state
        value = ((value ^ (value >> 30)) * 0xBF58476D1CE4E5B9) & self._MASK
        value = ((value ^ (value >> 27)) * 0x94D049BB133111EB) & self._MASK
        return value ^ (value >> 31)

    def randbelow(self, upper_bound: int) -> int:
        if upper_bound <= 0:
            raise ValueError("upper_bound must be positive")
        return self.next_u64() % upper_bound

    def randint(self, minimum: int, maximum: int) -> int:
        if maximum < minimum:
            raise ValueError("maximum must be greater than or equal to minimum")
        return minimum + self.randbelow(maximum - minimum + 1)

    def weighted_index(self, weights: list[int]) -> int:
        if not weights or any(weight <= 0 for weight in weights):
            raise ValueError("weights must be a non-empty list of positive integers")
        draw = self.randbelow(sum(weights))
        cumulative = 0
        for index, weight in enumerate(weights):
            cumulative += weight
            if draw < cumulative:
                return index
        raise AssertionError("weighted draw escaped its validated range")
