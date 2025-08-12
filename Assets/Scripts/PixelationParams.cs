using UnityEngine;

[ExecuteAlways]
public class PixelationParams : MonoBehaviour
{
    public Material pixelationMat; // 指向你這個 Shader Graph 產生的材質

    void LateUpdate()
    {
        if (pixelationMat == null) return;
        pixelationMat.SetFloat("_ScreenWidth",  Screen.width);
        pixelationMat.SetFloat("_ScreenHeight", Screen.height);
    }
}
