# 邊緣檢測後處理效果使用說明

## 概述
這個邊緣檢測後處理效果是從Godot著色器轉換而來，可以在Unity URP（Universal Render Pipeline）中使用。它能夠檢測場景中的邊緣並添加描邊效果，創造出像素化的視覺風格。

## 文件說明

### 1. EdgeDetectionPostProcess.shader
- **位置**: `Assets/Shaders/EdgeDetectionPostProcess.shader`
- **功能**: 主要的邊緣檢測著色器
- **特點**: 
  - 使用深度和法線信息進行邊緣檢測
  - 支持光照效果
  - 可調整的參數

### 2. EdgeDetectionPostProcess.cs
- **位置**: `Assets/Scripts/EdgeDetectionPostProcess.cs`
- **功能**: 簡單的後處理腳本，可以直接添加到相機上
- **使用方法**: 將此腳本添加到相機GameObject上

### 3. EdgeDetectionRenderPass.cs
- **位置**: `Assets/Scripts/EdgeDetectionRenderPass.cs`
- **功能**: URP渲染器功能，更專業的後處理實現
- **使用方法**: 添加到URP渲染器資源中

## 安裝步驟

### 方法一：使用簡單腳本（推薦初學者）

1. 確保項目使用URP渲染管線
2. 將 `EdgeDetectionPostProcess.shader` 放入 `Assets/Shaders/` 文件夾
3. 將 `EdgeDetectionPostProcess.cs` 放入 `Assets/Scripts/` 文件夾
4. 在場景中找到主相機
5. 將 `EdgeDetectionPostProcess` 腳本添加到相機GameObject上
6. 在Inspector中調整參數

### 方法二：使用URP渲染器功能（推薦專業用戶）

1. 確保項目使用URP渲染管線
2. 將所有文件放入對應文件夾
3. 在Project窗口中找到URP渲染器資源（通常在 `Assets/Settings/` 文件夾）
4. 選擇渲染器資源，在Inspector中點擊 "Add Renderer Feature"
5. 選擇 "Edge Detection Renderer Feature"
6. 調整參數設置

## 參數說明

### 基本參數
- **Light Intensity**: 光照強度 (0.0 - 3.0)
- **Line Alpha**: 線條透明度 (0.0 - 1.0)
- **Use Lighting**: 是否使用光照效果
- **Line Highlight**: 線條高亮強度 (0.0 - 1.0)
- **Line Shadow**: 線條陰影強度 (0.0 - 1.0)

### 檢測參數
- **Edge Threshold**: 邊緣檢測閾值 (0.0 - 1.0)
- **Normal Threshold**: 法線檢測閾值 (0.0 - 1.0)

## 性能優化建議

1. **降低解析度**: 如果性能有問題，可以降低後處理的解析度
2. **調整閾值**: 適當調整Edge Threshold和Normal Threshold可以減少不必要的邊緣檢測
3. **關閉光照**: 如果不需要光照效果，可以關閉Use Lighting選項

## 故障排除

### 常見問題

1. **著色器找不到**
   - 確保著色器文件在正確位置
   - 檢查著色器是否有編譯錯誤

2. **效果不顯示**
   - 確保相機有深度紋理
   - 檢查URP設置是否啟用深度紋理

3. **性能問題**
   - 降低解析度
   - 調整檢測參數
   - 考慮使用更簡單的邊緣檢測方法

## 自定義修改

### 修改檢測算法
在著色器的fragment函數中，您可以修改邊緣檢測的邏輯：
- 調整UVOffsets數組來改變採樣模式
- 修改depthDifference和normalDifference的計算方式
- 調整smoothstep函數的參數

### 添加新的參數
1. 在Properties中添加新參數
2. 在CBUFFER中添加對應變量
3. 在C#腳本中添加設置方法
4. 在著色器中使用新參數

## 技術細節

### 邊緣檢測原理
1. **深度檢測**: 比較當前像素與鄰近像素的深度差異
2. **法線檢測**: 比較當前像素與鄰近像素的法線方向差異
3. **組合檢測**: 將深度和法線檢測結果結合，生成最終的邊緣遮罩

### 渲染流程
1. 採樣深度紋理和法線紋理
2. 計算鄰近像素的差異
3. 應用閾值過濾
4. 生成邊緣遮罩
5. 應用光照效果（可選）
6. 輸出最終顏色

## 版本信息
- Unity版本: 2021.3 LTS 或更高
- URP版本: 12.0 或更高
- 原始來源: Godot邊緣檢測著色器 