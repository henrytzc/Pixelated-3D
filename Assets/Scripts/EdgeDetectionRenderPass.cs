using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class EdgeDetectionRenderPass : ScriptableRenderPass
{
    private Material edgeDetectionMaterial;
    private RenderTargetIdentifier source;
    private RenderTargetIdentifier destination;
    private string profilerTag;
    
    private EdgeDetectionSettings settings;
    
    public EdgeDetectionRenderPass(string profilerTag, EdgeDetectionSettings settings)
    {
        this.profilerTag = profilerTag;
        this.settings = settings;
        
        // 設置渲染事件
        renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    }
    
    public void Setup(RenderTargetIdentifier source, RenderTargetIdentifier destination)
    {
        this.source = source;
        this.destination = destination;
        
        // 創建材質
        if (edgeDetectionMaterial == null)
        {
            Shader shader = Shader.Find("Custom/EdgeDetectionPostProcess");
            if (shader != null)
            {
                edgeDetectionMaterial = new Material(shader);
            }
        }
    }
    
    [System.Obsolete]
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (edgeDetectionMaterial == null)
            return;
            
        CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
        
        try
        {
            // 設置材質參數
            edgeDetectionMaterial.SetFloat("_LightIntensity", settings.lightIntensity);
            edgeDetectionMaterial.SetFloat("_LineAlpha", settings.lineAlpha);
            edgeDetectionMaterial.SetFloat("_UseLighting", settings.useLighting ? 1.0f : 0.0f);
            edgeDetectionMaterial.SetFloat("_LineHighlight", settings.lineHighlight);
            edgeDetectionMaterial.SetFloat("_LineShadow", settings.lineShadow);
            edgeDetectionMaterial.SetFloat("_EdgeThreshold", settings.edgeThreshold);
            edgeDetectionMaterial.SetFloat("_NormalThreshold", settings.normalThreshold);
            
            // 執行後處理
            cmd.Blit(source, destination, edgeDetectionMaterial);
            
            context.ExecuteCommandBuffer(cmd);
        }
        finally
        {
            CommandBufferPool.Release(cmd);
        }
    }
    
    public void Dispose()
    {
        if (edgeDetectionMaterial != null)
        {
            Object.DestroyImmediate(edgeDetectionMaterial);
        }
    }
}

public class EdgeDetectionRendererFeature : ScriptableRendererFeature
{
    public EdgeDetectionSettings settings = new EdgeDetectionSettings();
    
    private EdgeDetectionRenderPass edgeDetectionPass;
    
    public override void Create()
    {
        edgeDetectionPass = new EdgeDetectionRenderPass("Edge Detection Post Process", settings);
    }
    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.postProcessEnabled)
        {
            edgeDetectionPass.Setup(renderer.cameraColorTargetHandle, renderer.cameraColorTargetHandle);
            renderer.EnqueuePass(edgeDetectionPass);
        }
    }
    
    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            edgeDetectionPass?.Dispose();
        }
    }
} 