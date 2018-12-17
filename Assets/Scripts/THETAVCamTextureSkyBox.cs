using UnityEngine;

public class THETAVCamTextureSkyBox : MonoBehaviour
{
    public Material skyboxMat;

    public Material effectMat;
    public bool isEffect = true;

    public int downSample = 0;
    public FilterMode filterMode = FilterMode.Bilinear;

    public RenderTexture outputTexture;

    THETAVCamTextureManager manager;

    private void Start()
    {
        manager = GetComponent<THETAVCamTextureManager>();

        if (manager != null)
        {
            int width = manager.webCamTexture.width >> downSample;
            int height = manager.webCamTexture.height >> downSample;
            outputTexture = new RenderTexture(width, height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Default);
            outputTexture.useMipMap = true;
            outputTexture.autoGenerateMips = true;
            outputTexture.filterMode = filterMode;

            if (skyboxMat != null)
            {
                RenderSettings.skybox = skyboxMat;
                skyboxMat.SetTexture("_MainTex", outputTexture);
            }

            Shader.SetGlobalTexture("_ThetaTex", outputTexture);
        }
    }

    private void LateUpdate()
    {
        if(manager != null)
        {
            if (effectMat != null && isEffect)
            {
                Graphics.Blit(manager.webCamTexture, outputTexture, effectMat);
            }
            else
            {
                Graphics.Blit(manager.webCamTexture, outputTexture);
            }

            if (skyboxMat != null)
            {
                RenderSettings.skybox = skyboxMat;
                skyboxMat.SetTexture("_MainTex", outputTexture);
            }

            Shader.SetGlobalTexture("_ThetaTex", outputTexture);
        }
    }
}
