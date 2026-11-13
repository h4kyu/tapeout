#include "Vpoker_native.h"
#include "verilated.h"
#include "capture.h"
#include <algorithm>
#include <cstring>
#include <memory>
#include <exception>

struct Simulation {
    VerilatedContext context;
    Vpoker_native model{&context};
    Capture capture;
    uint64_t cycles = 0, presses = 0;
    bool decode;
    explicit Simulation(bool decode_) : decode(decode_) {
        model.clk = 0; model.rst_n = 0; model.ena = 1; model.ui_in = 0; model.uio_in = 42;
    }
    ~Simulation() { model.final(); }
};
// Fixed-width ABI, mirrored by ctypes. All model access belongs to one caller.
struct State {
    uint64_t cycles, presses, frames, errors;
    uint32_t cards, holds, state, balance, category, payout, ready, status;
};
extern "C" {
void* poker_create(int decode) noexcept {
    try { return new Simulation(decode); } catch (...) { return nullptr; }
}
void poker_destroy(void* ptr) noexcept { delete static_cast<Simulation*>(ptr); }
void poker_inputs(void* ptr, uint8_t ui, uint8_t seed, uint8_t reset) noexcept {
    auto& s = *static_cast<Simulation*>(ptr);
    s.model.ui_in = ui; s.model.uio_in = seed; s.model.rst_n = reset;
}
// Trace is caller-owned, bounded by n <= 16384; nullptr is the live fast path.
int poker_advance(void* ptr, uint32_t n, uint8_t* trace) noexcept {
    if (n > 16384) return -1;
    try {
        auto& s = *static_cast<Simulation*>(ptr);
        for (uint32_t i = 0; i < n; ++i) {
            s.model.clk = 0; s.model.eval(); s.context.timeInc(20);
            uint8_t pins = s.model.uo_out;
            if (trace) trace[i] = pins;
            if (s.decode) s.capture.sample(pins, !s.model.rst_n);
            s.presses += s.model.accepted;
            s.model.clk = 1; s.model.eval(); s.context.timeInc(20);
            ++s.cycles;
        }
        return 0;
    } catch (...) { return -2; }
}
void poker_state(void* ptr, State* out) noexcept {
    auto& s = *static_cast<Simulation*>(ptr); auto& m = s.model; auto& c = s.capture;
    *out = {s.cycles, s.presses, c.frames, c.errors, m.cards, m.holds, m.state,
            m.balance, m.category, m.payout, c.ready, c.status};
}
uint64_t poker_frame(void* ptr, uint8_t* out, uint64_t after) noexcept {
    auto& c = static_cast<Simulation*>(ptr)->capture;
    if (!c.ready || c.frames == after) return 0;
    std::memcpy(out, c.latest.get(), Capture::bytes); return c.frames;
}
// Standalone decoder entrypoints for synthetic malformed-sync equivalence tests.
void* capture_create() noexcept { try { return new Capture; } catch (...) { return nullptr; } }
void capture_destroy(void* ptr) noexcept { delete static_cast<Capture*>(ptr); }
void capture_feed(void* ptr, const uint8_t* pins, uint32_t n, int reset) noexcept {
    auto& c = *static_cast<Capture*>(ptr);
    for (uint32_t i = 0; i < n; ++i) c.sample(pins[i], reset);
}
void capture_state(void* ptr, uint64_t* out) noexcept {
    auto& c = *static_cast<Capture*>(ptr);
    out[0] = c.frames; out[1] = c.errors; out[2] = c.ready;
}
uint64_t capture_frame(void* ptr, uint8_t* out) noexcept {
    auto& c = *static_cast<Capture*>(ptr);
    if (!c.ready) return 0;
    std::memcpy(out, c.latest.get(), Capture::bytes); return c.frames;
}
}
