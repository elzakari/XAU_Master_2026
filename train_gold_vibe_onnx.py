import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
import skl2onnx
from skl2onnx.common.data_types import FloatTensorType

print("Initializing MT5...")
if not mt5.initialize():
    print("MT5 initialize failed, error code =", mt5.last_error())
    quit()

symbol = "XAUUSD"
print(f"Pulling M5 {symbol} Data for training...")

# Pull M5 Gold Data (last 50,000 bars)
rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M5, 0, 50000)

if rates is None:
    print(f"Failed to get data for {symbol}. Error: {mt5.last_error()}")
    print("Trying 'GOLD'...")
    symbol = "GOLD"
    rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M5, 0, 50000)
    
if rates is None:
    print("Failed to get data for GOLD either. Giving up.")
    mt5.shutdown()
    quit()

print(f"Got {len(rates)} bars.")

df = pd.DataFrame(rates)
df['time'] = pd.to_datetime(df['time'], unit='s')

print("Constructing Vibe Features...")
# F1: Relative Volatility (ATR5 / ATR100 approx)
df['tr'] = df['high'] - df['low']
df['atr5'] = df['tr'].rolling(5).mean()
df['atr100'] = df['tr'].rolling(100).mean()
df['f1_rel_vol'] = df['atr5'] / df['atr100']

# F2: Liquidity Gap ((High - Low) / Volume)
df['f2_liq_gap'] = df['tr'] / (df['tick_volume'] + 1) # +1 to avoid div by zero

# F3: DXY Divergence (Proxy using inverted Gold returns for now)
df['gold_ret'] = df['close'].pct_change()
df['f3_dxy_div'] = -df['gold_ret']

# F4: Acceleration (Delta of Velocity)
df['velocity'] = df['close'] - df['close'].shift(1)
df['f4_accel'] = df['velocity'] - df['velocity'].shift(1)

# F5: Time of Day Vibe
df['f5_time_vibe'] = df['time'].dt.hour / 24.0

# Target: Did price move favorably in the next 5 bars?
df['future_move'] = df['close'].shift(-5) - df['close']
# Normalize target to 0-1 range for a "Confidence Score"
df['target'] = (df['future_move'] > 0.50).astype(int)

df = df.dropna()

print(f"Training Random Forest AI Model on {len(df)} samples...")
features = ['f1_rel_vol', 'f2_liq_gap', 'f3_dxy_div', 'f4_accel', 'f5_time_vibe']
X = df[features].astype(np.float32)
y = df['target'].astype(np.float32)

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Use Regressor to output a smooth probability score (0.0 to 1.0)
model = RandomForestRegressor(n_estimators=100, max_depth=5, random_state=42)
model.fit(X_train, y_train)

score = model.score(X_test, y_test)
print(f"Model R^2 Score: {score:.2f}")

print("Exporting to ONNX format...")
# Define the input type (1 row, 5 float features)
initial_type = [('float_input', FloatTensorType([None, 5]))]
onx = skl2onnx.convert_sklearn(model, initial_types=initial_type)

with open("gold_vibe.onnx", "wb") as f:
    f.write(onx.SerializeToString())

print("=========================================")
print("SUCCESS: Saved 'gold_vibe.onnx'.")
print("Move this file to your MQL5/Files/ folder.")
print("=========================================")

mt5.shutdown()