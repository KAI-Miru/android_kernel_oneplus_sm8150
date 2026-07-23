# Miru H.40 4.14.241 changelog

## User-visible release summary

- Updated the OnePlus 7 Pro Miru H.40 kernel from Linux `4.14.210` to
  `4.14.241`.
- Includes the Android common stable security and correctness fixes from
  `4.14.211` through `4.14.241`.
- Corrected dma-buf ownership and release handling to avoid the downstream
  lifetime/list double-free condition.
- Corrected QRTR packet allocation/lifetime handling. This fixes the
  splash-screen boot loop that affected the earlier 4.14.241 candidates.
- Restored normal GLINK RX error propagation while retaining the required
  missing-channel FIFO advance.
- The device-tested source boots on the OnePlus 7 Pro and retains the existing
  H.40 functionality: WLAN, audio, modem IPC, storage, display, touch,
  charging, suspend/resume, and the other established device interfaces.

## Validation note

The confirmed phone test used
`4.14.241-miru-h40-lts241-qrtr-ci6+`. The production workflow may issue a
new release suffix together with a freshly built 32-module drop-in package;
that candidate is separately identified and is not advertised as phone-tested
until it receives its own device test.

No speculative performance, battery-life, or feature claims are made by this
release note.
