#pragma once
#include <cstdint>
#include <utility>
#include <memory>

// Same external-pin timing contract as vga_capture.py. No model hierarchy used.
struct Capture {
    static constexpr unsigned bytes = 640 * 480 * 4;
    std::unique_ptr<uint8_t[]> drawing{new uint8_t[bytes]}, latest{new uint8_t[bytes]};
    uint64_t frames = 0, errors = 0;
    int x = -1, y = -1, previous_h = -1, previous_v = -1, since_h = -1;
    unsigned count = 0;
    bool collecting = false, ready = false;
    // 0 waiting, 1 acquiring, 2 captured; 3..7 malformed timing/blanking.
    unsigned status = 0;
    void reset() {
        x = y = previous_h = previous_v = since_h = -1;
        count = 0; collecting = ready = false; status = 0;
    }
    void lose(unsigned reason) {
        ++errors; x = y = -1; collecting = false; count = 0; status = reason;
    }
    void sample(uint8_t pins, bool reset_active) {
        if (reset_active) { reset(); return; }
        int h = pins >> 7, v = (pins >> 3) & 1;
        bool rising_h = previous_h == 0 && h == 1;
        bool vertical_edge = previous_v != -1 && previous_v != v;
        if (since_h != -1) ++since_h;
        if (x != -1 && ++x == 800) x = 0;
        if (rising_h) {
            if (since_h != -1 && since_h != 800) lose(3);
            since_h = 0; x = 752;
        }
        if (x != -1) {
            if (h != !(x >= 656 && x < 752)) lose(4);
            else if (vertical_edge) {
                if (x != 0) lose(5);
                else if (y != -1 && (y + 1) % 525 != (v ? 492 : 490)) lose(6);
                else { y = v ? 492 : 490; collecting = false; count = 0; status = 1; }
            } else if (x == 0 && y != -1) { if (++y == 525) y = 0; }
        }
        if (x != -1 && y != -1) {
            if (v != !(y >= 490 && y < 492)) lose(6);
            else {
                if (x == 0 && y == 0) { collecting = true; count = 0; }
                unsigned r = ((pins & 1) << 1) | ((pins >> 4) & 1);
                unsigned g = (pins & 2) | ((pins >> 5) & 1);
                unsigned b = ((pins >> 1) & 2) | ((pins >> 6) & 1);
                if (x >= 640 || y >= 480) { if (r || g || b) lose(7); }
                else if (collecting) {
                    auto p = drawing.get() + (y * 640 + x) * 4;
                    p[0] = r * 85; p[1] = g * 85; p[2] = b * 85; p[3] = 255;
                    ++count;
                    if (x == 639 && y == 479) {
                        if (count == 640 * 480) {
                            drawing.swap(latest); ++frames; ready = true; status = 2;
                        }
                        collecting = false;
                    }
                }
            }
        }
        previous_h = h; previous_v = v;
    }
};
