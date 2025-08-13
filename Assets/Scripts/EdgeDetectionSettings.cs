using UnityEngine;

[System.Serializable]
public class EdgeDetectionSettings
{
    [Range(0.0f, 3.0f)]
    public float lightIntensity = 1.25f;
    
    [Range(0.0f, 1.0f)]
    public float lineAlpha = 0.7f;
    
    public bool useLighting = true;
    
    [Range(0.0f, 1.0f)]
    public float lineHighlight = 0.2f;
    
    [Range(0.0f, 1.0f)]
    public float lineShadow = 0.55f;
    
    [Range(0.0f, 1.0f)]
    public float edgeThreshold = 0.25f;
    
    [Range(0.0f, 1.0f)]
    public float normalThreshold = 0.2f;
} 