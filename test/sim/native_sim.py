"""Single-owner ctypes adapter. Ordinary playback never copies pixel traces."""
import ctypes as C
from sim.build_native import build
from sim.poker_sim import Snapshot

BATCH = 16384
FRAME_BYTES = 640 * 480 * 4


class State(C.Structure):
    _fields_ = [(name, C.c_uint64) for name in ('cycles', 'presses', 'frames', 'errors')] + [
        (name, C.c_uint32) for name in ('cards', 'holds', 'state', 'balance', 'category', 'payout', 'ready', 'status')]


def load_library(debounce=5):
    lib = C.CDLL(str(build(debounce)))
    signatures = {
        'poker_create': ([C.c_int], C.c_void_p),
        'poker_destroy': ([C.c_void_p], None),
        'poker_inputs': ([C.c_void_p, C.c_uint8, C.c_uint8, C.c_uint8], None),
        'poker_advance': ([C.c_void_p, C.c_uint32, C.c_void_p], C.c_int),
        'poker_state': ([C.c_void_p, C.POINTER(State)], None),
        'poker_frame': ([C.c_void_p, C.c_void_p, C.c_uint64], C.c_uint64),
        'capture_create': ([], C.c_void_p), 'capture_destroy': ([C.c_void_p], None),
        'capture_feed': ([C.c_void_p, C.c_void_p, C.c_uint32, C.c_int], None),
        'capture_state': ([C.c_void_p, C.c_void_p], None),
        'capture_frame': ([C.c_void_p, C.c_void_p], C.c_uint64),
    }
    for name, (args, result) in signatures.items():
        fn = getattr(lib, name); fn.argtypes = args; fn.restype = result
    return lib


class NativeDriver:
    def __init__(self, debounce=5, decode=True):
        self.lib = load_library(debounce)
        self.handle = self.lib.poker_create(decode)
        if not self.handle:
            raise RuntimeError('Could not allocate native simulation')
        self.debounce_cycles = debounce
        self.cycle_observers = []
        self.cycles = self.accepted_presses = 0
        self.ui_in = 0; self.seed = 42; self.rst_n = 0
        self.trace = (C.c_uint8 * BATCH)()
        self.frame_buffer = (C.c_uint8 * FRAME_BYTES)()

    def close(self):
        if self.handle:
            self.lib.poker_destroy(self.handle)
            self.handle = None

    def write(self, **pins):
        self.ui_in = pins.get('ui_in', self.ui_in)
        self.seed = pins.get('uio_in', self.seed)
        self.rst_n = pins.get('rst_n', self.rst_n)
        self.lib.poker_inputs(self.handle, self.ui_in, self.seed, self.rst_n)

    def metrics(self):
        result = State()
        self.lib.poker_state(self.handle, C.byref(result))
        return result

    async def advance(self, cycles=1):
        before = self.metrics().presses
        remaining = cycles
        while remaining:
            n = min(remaining, BATCH)
            trace = self.trace if self.cycle_observers else None
            if self.lib.poker_advance(self.handle, n, trace):
                raise RuntimeError('Native simulation advance failed')
            if trace is not None:
                for pins in trace[:n]:
                    for observer in self.cycle_observers:
                        observer(pins, not self.rst_n)
            remaining -= n
        self.cycles += cycles
        self.accepted_presses += self.metrics().presses - before

    def snapshot(self):
        s = self.metrics()
        return Snapshot(s.state, tuple((s.cards >> (6*i)) & 63 for i in range(5)),
                        s.holds, s.balance, s.category, s.payout,
                        s.state in (0, 5) and s.balance >= 5)

    def latest_rgba(self, after=0):
        number = self.lib.poker_frame(self.handle, self.frame_buffer, after)
        return (number, bytes(self.frame_buffer)) if number else None
