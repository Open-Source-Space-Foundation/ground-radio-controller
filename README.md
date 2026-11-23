# GRC test image D (not for merge)

Radio Stick V2 test build for the 128-byte control-port downlink fix (CDC ACM TX).
Image D is PR #39 (remote bootloader entry) plus the fix: when the TX queue is full
the frame is dropped but reported OK, so the downlink no longer wedges when the port
sits unread, and the writer backs off instead of spinning when USB takes no bytes.

| File | Notes |
|---|---|
| `grc-v2-D.uf2` | Radio Stick V2 (RP2350) firmware |
| `dict-D.json` | matching F Prime dictionary, projectVersion `4bba3ad-dirty`, fprime-zephyr `platform-guard-4.3-pin-4-g8d82da2-dirty` |
| `SHA256SUMS` | `shasum -a 256 -c SHA256SUMS` |

Flash: `picotool load -v -x grc-v2-D.uf2` (or via `remote-flash.sh` on an image with PR #39).
Hardware status: second bench run on V2 stick B339212D7B7BAC02 pending.
