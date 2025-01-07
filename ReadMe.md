# MetaTrader 5 Utilities

A collection of custom Expert Advisors (EAs) and tools for MetaTrader 5, designed to enhance your trading experience.

## 📌 Current Features

### Auto Stop Loss EA

Automatically manages stop losses for your manually opened trades with these features:

- Sets initial stop loss automatically when you open a position
- Dynamic trailing stop that adapts to market volatility using ATR
- Option to use fixed pip-based stops
- Minimum distance protection to avoid getting stopped out too quickly

## 🚀 Quick Start Guide

### Basic Installation (Just want to use the EA?)

1. Download this repository by clicking the green "Code" button and selecting "Download ZIP"
2. Extract the ZIP file to a temporary location
3. Open MetaTrader 5
4. Click File → Open Data Folder
5. Navigate to MQL5 → Experts
6. Copy the "Abhis_EAs" folder from the downloaded files to this location
7. Restart MetaTrader 5

### Using the Auto Stop Loss EA

1. In MetaTrader 5, open the Navigator panel (Ctrl+N)
2. Find "Abhis_EAs" under "Expert Advisors"
3. Double-click "Auto_SL_EA" to add it to your chart
4. Configure the settings:

   - FixedSLPips: Initial stop loss distance (default: 20 pips)
   - UseATR: Set to true for dynamic stops based on volatility
   - ATRPeriod: Look-back period for ATR (default: 14)
   - ATRMultiplier: How wide to set the stop loss (default: 1.5)
   - EnableTrailing: Turn trailing stop on/off
   - MinimumPips: Minimum distance for trailing stop

5. Click "OK" to start the EA
6. Look for a smiley face in the top right corner of your chart
7. Now open trades normally - the EA will manage your stop losses automatically

## 👨‍💻 Developer Setup (Want to modify the code?)

### Prerequisites

1. Install Visual Studio Code
2. Install MetaTrader 5
3. Install Git (optional, for version control)

### Development Environment Setup

1. Clone or download this repository
2. Open Command Prompt as Administrator
3. Navigate to your repository folder
4. Run `autobuild.bat` to enable auto-compilation

### Making Changes

1. Open the project folder in VS Code
2. Make changes to any .mq5 file
3. Save your changes
4. The watch script will automatically compile
5. Changes appear instantly in MetaTrader 5

## 📊 EA Parameters Explained

### Auto Stop Loss EA Settings

- **FixedSLPips** (default: 20.0)

  - Fixed stop loss distance in pips
  - Used when UseATR is false
  - Example: 20 pips = $20 on a standard lot EURUSD

- **UseATR** (default: true)

  - Enables dynamic stop loss based on market volatility
  - True: Uses ATR for dynamic stops
  - False: Uses fixed pips distance

- **ATRPeriod** (default: 14)

  - Lookback period for ATR calculation
  - Higher = smoother, slower adaptation
  - Lower = faster adaptation to volatility

- **ATRMultiplier** (default: 1.5)

  - Multiplier for initial stop loss distance
  - Higher = wider stops
  - Lower = tighter stops

- **TrailATRMultiplier** (default: 1.0)

  - Multiplier for trailing stop distance
  - Usually lower than ATRMultiplier
  - Controls how closely price is followed

- **MinimumPips** (default: 5)
  - Minimum trailing distance in pips
  - Prevents too-tight stops
  - Safety mechanism against whipsaws

## ⚠️ Important Notes

1. Always test on a demo account first
2. Start with default settings and adjust gradually
3. Keep the watch script running while developing
4. Backup your modifications regularly

## 🤝 Contributing

Feel free to:

1. Fork the repository
2. Create a new branch
3. Submit pull requests with improvements

## 📝 License

This project is licensed under MIT - feel free to use and modify for your personal trading.

## 💡 Support

If you encounter any issues:

1. Check the build_log.txt file for compilation errors
2. Verify the EA shows a smiley face on the chart
3. Check the "Experts" tab in MT5 for error messages
4. Create an issue in this repository

Good luck with your trading! 🚀
