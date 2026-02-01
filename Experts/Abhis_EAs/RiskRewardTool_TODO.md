# RiskRewardTool - Future Enhancements

## High-Impact Features

### 1. Multiple Take Profit Levels (TP1, TP2, TP3)
- Add support for multiple TP lines (TP1, TP2, TP3)
- Configurable partial close percentages (e.g., 50% at TP1, 30% at TP2, 20% at TP3)
- Each TP level shows its own reward calculation
- Visual distinction between TP levels (different colors/styles)
- Panel section to configure TP levels and percentages

### 2. Break-Even Line
- Auto-calculate break-even price including spread/commission
- Show a visual break-even line on chart
- Option to auto-move SL to break-even after TP1 is hit
- Display break-even distance in pips

### 3. Lock Lines Toggle
- Add a lock/unlock button on the panel
- When locked, lines cannot be dragged accidentally
- Visual indicator showing locked state (e.g., padlock icon or color change)
- Keyboard shortcut to toggle lock state

---

## Quality of Life

### 4. Keyboard Shortcuts
- `R` - Reset tool / clear all lines
- `F` - Flip direction (Long <-> Short)
- `L` - Lock/unlock lines
- `1/2/3` - Quick switch between risk modes
- `+/-` - Adjust risk value
- `Esc` - Cancel current operation
- Display shortcut hints in panel or tooltip

### 5. Snap to Price Levels
- Option to snap lines to round numbers (e.g., 1.0800, 1.0850)
- Configurable snap increment (10 pips, 50 pips, 100 pips)
- Optional snap to recent swing highs/lows
- Hold Shift to temporarily disable snap while dragging

### 6. Trade Templates
- Save current setup as a named template
- Quick-load common setups:
  - "1R Scalp" - 1:1 RR, 0.5% risk
  - "2R Day Trade" - 1:2 RR, 1% risk
  - "3R Swing" - 1:3 RR, 2% risk
- Store templates in GlobalVariables or file
- Template selector dropdown in panel

---

## Analytics

### 7. Session Stats
- Track trades placed via the tool
- Display running statistics:
  - Win/Loss count and ratio
  - Average R multiple achieved
  - Total P&L for session
  - Best/worst trade
- Reset stats button
- Optional: persist stats across sessions

### 8. Screenshot Capture
- One-click screenshot of current chart with trade setup
- Auto-save to designated folder
- Include timestamp and symbol in filename
- Option to copy to clipboard
- Useful for trade journaling

---

## Additional Ideas

### 9. Sound Alerts
- Alert when price approaches entry/SL/TP
- Configurable distance threshold for alerts
- Different sounds for different events

### 10. Trade Journal Integration
- Auto-log trade setups to CSV/Excel file
- Record: symbol, direction, entry, SL, TP, risk, RR, timestamp
- Optional notes field before placing trade

### 11. One-Click Trading Mode
- Toggle between confirmation mode and instant mode
- Instant mode places orders immediately without dialog
- Clear visual warning when instant mode is active

### 12. Duplicate to Chart
- Button to copy current tool setup to another open chart
- Useful for correlated pairs or multiple timeframe analysis

---

## Implementation Priority

| Priority | Feature | Complexity | Impact |
|----------|---------|------------|--------|
| 1 | Lock Lines Toggle | Low | High |
| 2 | Keyboard Shortcuts | Medium | High |
| 3 | Multiple TP Levels | High | High |
| 4 | Break-Even Line | Medium | Medium |
| 5 | Screenshot Capture | Low | Medium |
| 6 | Trade Templates | Medium | Medium |
| 7 | Snap to Price Levels | Medium | Medium |
| 8 | Session Stats | Medium | Low |

---

## Notes

- Start with low-complexity, high-impact features first
- Multiple TP levels will require significant refactoring of line management
- Consider user preferences for all new features (input parameters)
- Maintain backward compatibility with existing saved states
