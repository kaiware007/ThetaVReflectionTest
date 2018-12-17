using UnityEngine;

public class THETAVCamTextureManager : MonoBehaviour
{

    #region define
    static readonly string theta_v_FullHD = "RICOH THETA V FullHD";
    static readonly string theta_v_4K = "RICOH THETA V 4K";

    static readonly string[] thetaCameraModeList =
    {
        theta_v_FullHD,
        theta_v_4K,
    };

    public enum THETA_V_CAMERA_MODE
    {
        THETA_V_FullHD,
        THETA_V_4K,
    }
    #endregion

    public THETA_V_CAMERA_MODE cameraMode = THETA_V_CAMERA_MODE.THETA_V_FullHD;

    protected WebCamTexture _webCamTexture = null;

    public WebCamTexture webCamTexture { get { return _webCamTexture; } }

    protected virtual void Initialize()
    {
        int cameraIndex = -1;

        WebCamDevice[] devices = WebCamTexture.devices;
        Debug.Log("DevicesLength:" + devices.Length.ToString());
        for (var i = 0; i < devices.Length; i++)
        {
            for (int j = 0; j < thetaCameraModeList.Length; j++)
            {
                Debug.Log("[" + i + "] " + devices[i].name);

                if (devices[i].name == thetaCameraModeList[(int)cameraMode])
                {
                    Debug.Log("[" + i + "] " + devices[i].name + " detected");
                    cameraIndex = i;
                    break;
                }
            }
            if (cameraIndex >= 0) break;
        }

        if (cameraIndex < 0)
        {
            Debug.LogError("THETA V Not found");
            return;
        }

        _webCamTexture = new WebCamTexture(devices[cameraIndex].name);
        if(_webCamTexture != null)
        {
            _webCamTexture.Play();
        }
    }

    private void Awake()
    {
        Initialize();
    }
}
