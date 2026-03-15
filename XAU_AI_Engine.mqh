//+------------------------------------------------------------------+
//|                                              XAU_AI_Engine.mqh   |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                          ONNX Neural Gatekeeper for XAU_Master   |
//+------------------------------------------------------------------+
#property strict

long m_onnx_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Load the ONNX Model                                              |
//+------------------------------------------------------------------+
bool LoadVibeModel(string fileName) {
    // Look in MQL5/Files/
    m_onnx_handle = OnnxCreate(fileName, ONNX_DEFAULT);
    if(m_onnx_handle == INVALID_HANDLE) {
        Print("AI Error: Could not load model '", fileName, "'. Ensure it is in MQL5/Files.");
        return false;
    }
    
    // Define input/output shapes for the ONNX tensor
    // 1 row, 5 features
    long inputs_shape[] = {1, 5}; 
    // 1 row, 1 output feature (Regression/Probability score)
    long outputs_shape[] = {1, 1}; 
    
    if(!OnnxSetInputShape(m_onnx_handle, 0, inputs_shape)) {
        Print("AI Error: Failed to set ONNX input shape.");
        return false;
    }
    
    if(!OnnxSetOutputShape(m_onnx_handle, 0, outputs_shape)) {
        Print("AI Error: Failed to set ONNX output shape.");
        return false;
    }
    
    Print("AI Vibe Model loaded successfully.");
    return true;
}

//+------------------------------------------------------------------+
//| Predict Vibe Score (0.0 to 1.0)                                  |
//+------------------------------------------------------------------+
float PredictVibe(float &features[]) {
    if(m_onnx_handle == INVALID_HANDLE) {
        Print("AI Warning: ONNX handle invalid. Failing Vibe Check.");
        return 0.0f; 
    }
    
    float output[1]; // Result: 0.0 (Bad Vibe) to 1.0 (Great Vibe)
    
    // Run the model
    if(!OnnxRun(m_onnx_handle, ONNX_NO_CONVERSION, features, output)) {
        // Print("AI Error: Prediction failed.");
        return 0.5f; // Return neutral score on failure to avoid spamming logs
    }
    
    return output[0]; 
}

//+------------------------------------------------------------------+
//| Feature 1: Relative Volatility ATR(5)/ATR(100)                   |
//+------------------------------------------------------------------+
float GetRelativeVolatility() {
    static int h5 = INVALID_HANDLE;
    static int h100 = INVALID_HANDLE;
    
    if(h5 == INVALID_HANDLE) h5 = iATR(_Symbol, PERIOD_CURRENT, 5);
    if(h100 == INVALID_HANDLE) h100 = iATR(_Symbol, PERIOD_CURRENT, 100);
    
    double atr5[1], atr100[1];
    if(CopyBuffer(h5, 0, 1, 1, atr5) > 0 && CopyBuffer(h100, 0, 1, 1, atr100) > 0) {
        if(atr100[0] > 0) return (float)(atr5[0] / atr100[0]);
    }
    return 1.0f;
}

//+------------------------------------------------------------------+
//| Feature 2: Liquidity Gap (High - Low) / Volume                   |
//+------------------------------------------------------------------+
float GetLiquidityScore() {
    MqlRates rates[1];
    // Use the last closed candle
    if(CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, rates) > 0) {
        if(rates[0].tick_volume > 0) {
            return (float)((rates[0].high - rates[0].low) / (double)rates[0].tick_volume);
        }
    }
    return 0.0f;
}

//+------------------------------------------------------------------+
//| Feature 3: DXY Divergence                                        |
//+------------------------------------------------------------------+
float GetDXYCorrelation() {
    // Use the momentum score we already calculate in XAU_DXY_Monitor
    return (float)GlobalVariableGet("XAU_DXY_MOMENTUM");
}

//+------------------------------------------------------------------+
//| Feature 4: Momentum Acceleration                                 |
//+------------------------------------------------------------------+
float GetMomentumAcceleration() {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_CURRENT, 1, 4, rates) >= 3) {
        // rates[0] = Bar 1, rates[1] = Bar 2, rates[2] = Bar 3
        double velocity1 = rates[0].close - rates[1].close;
        double velocity2 = rates[1].close - rates[2].close;
        return (float)(velocity1 - velocity2);
    }
    return 0.0f;
}

//+------------------------------------------------------------------+
//| Feature 5: Time of Day Vibe                                      |
//+------------------------------------------------------------------+
float GetTimeOfDayVibe() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return (float)(dt.hour / 24.0);
}
