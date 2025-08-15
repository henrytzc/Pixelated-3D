using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// 對低解析度的 RenderTexture 做「多數決像素化」(mode filter)。
/// 步驟：讀取低清 RT -> 以區塊為單位做顏色投票 -> 產生結果 Texture2D -> 顯示在 RawImage。
/// 追求簡單易懂版：純 C#，效能一般；先跑通概念用。
/// </summary>
public class ModePixelateSimple : MonoBehaviour
{
    [Header("輸入 / 輸出")]
    public RenderTexture lowResSource; // 你原本的低解析度 RT（送給 RawImage 的那張）
    public RawImage targetUI;          // 顯示結果的 RawImage（可用你原本那個）

    [Header("像素化參數")]
    [Tooltip("每個區塊的大小（像素）。例如 8 代表 8x8 一塊。")]
    public int blockSize = 8;

    [Tooltip("每個通道量化等級（2 表示每通道 2 等級；越高越精細但計數更慢）。建議 4~8。")]
    [Range(2, 16)] public int levelsPerChannel = 4;

    // 內部暫存
    Texture2D _readTex;   // 用來讀取低清 RT
    Texture2D _outTex;    // 輸出結果
    Color32[] _srcPixels;
    Color32[] _dstPixels;
    int[] _hist;          // 直方圖：levels^3 大小，重複利用避免 GC

    void LateUpdate()
    {
        if (lowResSource == null || targetUI == null) return;

        // 準備輸入/輸出貼圖
        EnsureTextures();

        // 1) 把低清 RT 讀進 _readTex
        var prev = RenderTexture.active;
        RenderTexture.active = lowResSource;
        _readTex.ReadPixels(new Rect(0, 0, lowResSource.width, lowResSource.height), 0, 0, false);
        _readTex.Apply(false, false);
        RenderTexture.active = prev;

        // 2) 拿到像素陣列
        _srcPixels = _readTex.GetPixels32(); // 低清像素
        if (_dstPixels == null || _dstPixels.Length != _srcPixels.Length)
            _dstPixels = new Color32[_srcPixels.Length];

        int w = _readTex.width;
        int h = _readTex.height;

        // 3) 逐區塊做「多數決顏色」
        int binCount = levelsPerChannel * levelsPerChannel * levelsPerChannel;
        if (_hist == null || _hist.Length != binCount)
            _hist = new int[binCount];

        for (int by = 0; by < h; by += blockSize)
        {
            for (int bx = 0; bx < w; bx += blockSize)
            {
                // 清空直方圖
                for (int i = 0; i < binCount; i++) _hist[i] = 0;

                int xEnd = Mathf.Min(bx + blockSize, w);
                int yEnd = Mathf.Min(by + blockSize, h);

                // 3a) 該區塊所有像素量化入桶 + 計數
                for (int y = by; y < yEnd; y++)
                {
                    int row = y * w;
                    for (int x = bx; x < xEnd; x++)
                    {
                        Color32 c = _srcPixels[row + x];
                        int bin = QuantizeToBin(c, levelsPerChannel);
                        _hist[bin]++;
                    }
                }

                // 3b) 找票數最多的桶
                int maxBin = 0, maxCnt = 0;
                for (int i = 0; i < binCount; i++)
                {
                    int cnt = _hist[i];
                    if (cnt > maxCnt) { maxCnt = cnt; maxBin = i; }
                }

                // 3c) 桶中心色當代表色（簡單快速）
                Color32 rep = BinToColor32(maxBin, levelsPerChannel);

                // 3d) 把整塊填代表色
                for (int y = by; y < yEnd; y++)
                {
                    int row = y * w;
                    for (int x = bx; x < xEnd; x++)
                        _dstPixels[row + x] = rep;
                }
            }
        }

        // 4) 回寫輸出貼圖 & 顯示
        _outTex.SetPixels32(_dstPixels);
        _outTex.Apply(false, false);
        targetUI.texture = _outTex; // RawImage 顯示結果
    }

    void EnsureTextures()
    {
        int w = lowResSource.width;
        int h = lowResSource.height;

        if (_readTex == null || _readTex.width != w || _readTex.height != h)
            _readTex = new Texture2D(w, h, TextureFormat.RGB24, false, false);

        if (_outTex == null || _outTex.width != w || _outTex.height != h)
            _outTex = new Texture2D(w, h, TextureFormat.RGB24, false, false);
    }

    // 將 Color32 量化到 (levels^3) 個桶之一
    static int QuantizeToBin(Color32 c, int levels)
    {
        // 將 0..255 映到 0..levels-1（用浮點更簡單易懂）
        int r = Mathf.Clamp(Mathf.FloorToInt((c.r / 255f) * levels), 0, levels - 1);
        int g = Mathf.Clamp(Mathf.FloorToInt((c.g / 255f) * levels), 0, levels - 1);
        int b = Mathf.Clamp(Mathf.FloorToInt((c.b / 255f) * levels), 0, levels - 1);
        return (r * levels + g) * levels + b;
    }

    // 從桶索引回推桶中心代表色
    static Color32 BinToColor32(int bin, int levels)
    {
        int r = bin / (levels * levels);
        int g = (bin / levels) % levels;
        int b = bin % levels;

        // 桶中心 = (index + 0.5) / levels
        byte R = (byte)Mathf.RoundToInt(((r + 0.5f) / levels) * 255f);
        byte G = (byte)Mathf.RoundToInt(((g + 0.5f) / levels) * 255f);
        byte B = (byte)Mathf.RoundToInt(((b + 0.5f) / levels) * 255f);
        return new Color32(R, G, B, 255);
    }
}
