using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class EdgeDetectionPostProcess : MonoBehaviour
{
    [Header("Edge Detection Settings")]
    public EdgeDetectionSettings settings = new EdgeDetectionSettings();
    
    [Header("References")]
    public Shader edgeDetectionShader;
    
    private Material edgeDetectionMaterial;
    private RenderTargetIdentifier cameraColorTarget;
    private RenderTargetIdentifier cameraDepthTarget;
    
    void Start()
    {
        // 如果沒有指定著色器，嘗試找到它
        if (edgeDetectionShader == null)
        {
            edgeDetectionShader = Shader.Find("Custom/EdgeDetectionPostProcess");
        }
        
        if (edgeDetectionShader != null)
        {
            edgeDetectionMaterial = new Material(edgeDetectionShader);
        }
        else
        {
            Debug.LogError("找不到邊緣檢測著色器！請確保著色器已正確導入。");
        }
    }
    
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (edgeDetectionMaterial == null)
        {
            Graphics.Blit(source, destination);
            return;
        }
        
        // 設置材質參數
        edgeDetectionMaterial.SetFloat("_LightIntensity", settings.lightIntensity);
        edgeDetectionMaterial.SetFloat("_LineAlpha", settings.lineAlpha);
        edgeDetectionMaterial.SetFloat("_UseLighting", settings.useLighting ? 1.0f : 0.0f);
        edgeDetectionMaterial.SetFloat("_LineHighlight", settings.lineHighlight);
        edgeDetectionMaterial.SetFloat("_LineShadow", settings.lineShadow);
        edgeDetectionMaterial.SetFloat("_EdgeThreshold", settings.edgeThreshold);
        edgeDetectionMaterial.SetFloat("_NormalThreshold", settings.normalThreshold);
        
        // 應用後處理效果
        Graphics.Blit(source, destination, edgeDetectionMaterial);
    }
    
    void OnDestroy()
    {
        if (edgeDetectionMaterial != null)
        {
            DestroyImmediate(edgeDetectionMaterial);
        }
    }
    
    // 提供公共方法來動態調整參數
    public void SetLightIntensity(float intensity)
    {
        settings.lightIntensity = Mathf.Clamp(intensity, 0.0f, 3.0f);
    }
    
    public void SetLineAlpha(float alpha)
    {
        settings.lineAlpha = Mathf.Clamp01(alpha);
    }
    
    public void SetUseLighting(bool useLighting)
    {
        settings.useLighting = useLighting;
    }
    
    public void SetEdgeThreshold(float threshold)
    {
        settings.edgeThreshold = Mathf.Clamp01(threshold);
    }
    
    public void SetNormalThreshold(float threshold)
    {
        settings.normalThreshold = Mathf.Clamp01(threshold);
    }
} 