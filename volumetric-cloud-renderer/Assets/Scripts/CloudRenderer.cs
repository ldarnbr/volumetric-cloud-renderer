// to be attached to the main camera.

using UnityEngine;

public class CloudRenderer : MonoBehaviour
{
    // the material containing the shader to render the clouds
    public Material CloudShaderMaterial;

    // the object for the cloud volume bounding box in the scene
    public GameObject CloudVolumeBounds;

    // DOCS:
    // https://docs.unity3d.com/6000.3/Documentation/ScriptReference/MonoBehaviour.OnRenderImage.html

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (CloudShaderMaterial != null && CloudVolumeBounds != null)
        {
            // get the boundary positions of the cloud volume from the object in the scene
            Bounds bounds = CloudVolumeBounds.GetComponent<Renderer>().bounds;
            Vector3 CloudVolumeMinBound = bounds.min;
            Vector3 CloudVolumeMaxBound = bounds.max;

            // give the shader the boundary positions
            CloudShaderMaterial.SetVector("_CloudVolumeMinBound", CloudVolumeMinBound);
            CloudShaderMaterial.SetVector("_CloudVolumeMaxBound", CloudVolumeMaxBound);

            // runs the shader on every pixel (Graphics.Blit) and outputs to the destination
            Graphics.Blit(source, destination, CloudShaderMaterial);
        } else
        {
            // cannot apply the post processing shader logic if the material/bounds dont exist
            Graphics.Blit(source, destination);
            return;
        }
    }
}
