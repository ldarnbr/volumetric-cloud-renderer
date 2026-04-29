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

    // this will control how much light the cloud absorbs via Beer-Lambert
    // Defaults to 1.0 so that the base transmittance is set to exp(-densityTotal).
    [Range(0f, 5f)]
    public float absorptionCoefficient = 1.0f;

    // sets the minimum noise value to contribute to the cloud density. A higher threshold means sparser clouds.
    [Range(0f, 1f)]
    public float densityThreshold = 0.1f;

    // controls the light scattering forward through the cloud, 0-1 weakest-strongest scattering
    [Range(0f, 1f)]
    public float scatterFactor = 0.3f;

    // controls how zoomed into the noise texture we are in the cloud volume box, effectively controlling the
    // size of the clouds themselves.
    [Range(0.001f, 0.05f)]
    public float cloudScale = 0.01f;

    // octaves represent the layers of noise to be combined. Layering reduces tiling effects at the cost of some performance.
    [Range(1, 4)]
    public int octaveCount = 4;

    public PerlinNoise3D PerlinNoiseGenerator;

    public Light sunLight;

    private Texture3D cachedNoiseTex;
    private Texture3D cachedPerlinTex;

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
            CloudShaderMaterial.SetFloat("_DensityThreshold", densityThreshold);
            CloudShaderMaterial.SetFloat("_ScatterFactor", scatterFactor);

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

            // now caches the Worley texture if one doesnt already exist. Measures time taken for performance benchmarking.
            if (cachedNoiseTex == null)
            {
                float worleyStartTime = Time.realtimeSinceStartup;
                cachedNoiseTex = NoiseGenerator.GenerateTexture();
                Debug.Log("Worley Generation Took: " + (Time.realtimeSinceStartup - worleyStartTime) + " seconds");
            }
            CloudShaderMaterial.SetTexture("_NoiseTex", cachedNoiseTex);

            CloudShaderMaterial.SetFloat("_AbsorptionCoefficient", absorptionCoefficient);

            // obtains the direction of the light emitted from the sun to pass to the shader for light marching
            // reverse with - to get the direction of the vector from the cloud position to the sun
            CloudShaderMaterial.SetVector("_SunDirection", -sunLight.transform.forward);
            // get the colour for tinting
            CloudShaderMaterial.SetVector("_SunColour", new Vector4(sunLight.color.r, sunLight.color.g, sunLight.color.b, 1));
            CloudShaderMaterial.SetFloat("_CloudScale", cloudScale);

            // now caches the Perlin texture if one doesnt already exist. Measures time taken for performance benchmarking.
            if (cachedPerlinTex == null)
            {
                float perlinStartTime = Time.realtimeSinceStartup;
                cachedPerlinTex = PerlinNoiseGenerator.GenerateTexture();
                Debug.Log("Perlin Generation Took: " + (Time.realtimeSinceStartup - perlinStartTime) + " seconds");
            }
            CloudShaderMaterial.SetTexture("_PerlinTex", cachedPerlinTex);

            // pass octave count to the shader for Fractal Brownian Motion noise layering
            CloudShaderMaterial.SetInt("_OctaveCount", octaveCount);

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
