// to be attached to the main camera.

using UnityEngine;

public class CloudRenderer : MonoBehaviour
{
    // the material containing the shader to render the clouds
    public Material CloudShaderMaterial;

    // the object for the cloud volume bounding box in the scene
    public GameObject CloudVolumeBounds;

    // reference to the noise generator to get the 3D texture from it in the shader
    public WorleyNoise3D NoiseGenerator;

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

            // passes the camera position to the shader. transfomr.position is the world position of the camera.
            CloudShaderMaterial.SetVector("_CameraWorldPosition", transform.position);

            // need to calculate the four corners of the camera frustum in world space
            // (at the far clipping plane to ensure we're getting the entire scene)
            Camera camera = GetComponent<Camera>();
            // four corners
            Vector3[] frustumCorners = new Vector3[4];
            camera.CalculateFrustumCorners(
                // represents the full screen in normalised coordinates
                new Rect(0, 0, 1, 1),
                camera.farClipPlane,
                Camera.MonoOrStereoscopicEye.Mono,
                frustumCorners
            );

            // converts the corners from camera space to world space using only rotation.
            // Only the direction matters because rays aren't points, so no translation is needed.
            CloudShaderMaterial.SetVector("_FrustumCornerTR", camera.transform.TransformDirection(frustumCorners[2]));
            CloudShaderMaterial.SetVector("_FrustumCornerBR", camera.transform.TransformDirection(frustumCorners[3]));
            CloudShaderMaterial.SetVector("_FrustumCornerTL", camera.transform.TransformDirection(frustumCorners[1]));
            CloudShaderMaterial.SetVector("_FrustumCornerBL", camera.transform.TransformDirection(frustumCorners[0]));

            // generates the 3D noise texture and passes it to the shader
            Texture3D noiseTex = NoiseGenerator.GenerateTexture();

            CloudShaderMaterial.SetTexture("_NoiseTex", noiseTex);

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
