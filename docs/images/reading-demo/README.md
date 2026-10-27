# Native reading demo sources

These images come from the actual EasyRead window running the UI from commit
`fda3cbabba525948a0e9caed0e6c6efe2af4cdc5`. A temporary local capture callback exported
only this sample query using AppKit view caching. The callback has been removed.
No desktop, browser, source document window, or other application is included.

The sample was selected in TextEdit and submitted through the real Option+D shortcut:

> Although the results initially appeared convincing, the researchers who reviewed the data warned that the conclusion would remain uncertain until the experiment had been independently replicated.

- `query.png`: the original text before results arrive.
- `translation.png`: translation visible while AI sentence analysis is loading.
- `analysis.png`: the completed analysis from DeepSeek / deepseek-flash.

The UI controls, text, colors, geometry and results are unmodified captures.
The promotional GIF adds an outer background, headings, framing and crossfades.
Waiting time is shortened; it is not a performance benchmark.

To regenerate on macOS with Swift and ffmpeg:

```bash
swift scripts/make-reading-demo.swift docs/images/reading-demo .tmp/reading-demo
ffmpeg -y -framerate 12 -i .tmp/reading-demo/frame-%03d.png \
  -vf 'split[a][b];[a]palettegen=stats_mode=full:reserve_transparent=0[p];[b][p]paletteuse=dither=none' \
  -loop 0 docs/images/ai-selection-translation.gif
```

## Capture hashes

- `query.png`: `3cf98e133571e7ac73f0123d8cc9c64241151be71422abf5c4bb1bd7fbcff0e5`
- `translation.png`: `c2047cf8d2d182d88da3e6fb1f035282143a3129a9f9a61c077b35886e3204e7`
- `analysis.png`: `e1866c735af49749e74cf288abccc004d779de7a2dd85b3bbaaf093d16672fc1`
