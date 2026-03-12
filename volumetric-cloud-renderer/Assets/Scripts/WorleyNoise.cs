using UnityEngine;

public class WorleyNoise : MonoBehaviour
{

    [Header("Texture Settings")]
    // dimensions of texture to generate
    public int textureSize = 256;
    // points contained in the texture (number of bubbles)
    public int pointCount = 50;
    // changing the seed should change the pattern of the noise
    public int seed = 30;


    // Start is called before the first frame update
    void Start()
    {
        Texture2D texture = GenerateTexture();
        // apply the texture to the material of the object this script is attached to
        GetComponent<Renderer>().material.mainTexture = texture;
    }

    Texture2D GenerateTexture()
    {
        Texture2D texture = new Texture2D(textureSize, textureSize);

        // seed the number generator to recreate patterns
        Random.InitState(seed);

        // 2D array of points to calculate the noise from
        Vector2[] points = new Vector2[pointCount];
        for (int i = 0; i < pointCount; i++)
        {
            // assign random values to all the points in the array
            points[i] = new Vector2(Random.value, Random.value);
        }

        for (int x = 0; x < textureSize; x++)
        {
            for (int y = 0; y < textureSize; y++)
            {
                // convert the pixel coordinates to be between 0 and 1
                float u = (float)x / textureSize;
                float v = (float)y / textureSize;
                Vector2 pixelPos = new Vector2(u, v);

                // set the highest value possible as the default minimum distance
                float minDist = float.MaxValue;

                // need to calculate the distance between the pixel and all the points to find which is closest
                foreach( Vector2 point in points)
                {
                    float dist = Vector2.Distance(pixelPos, point);
                    // stores the minimum distance
                    if (dist < minDist)
                    {
                        minDist = dist;
                    }
                }

                // maximum distance for one 1x1 square is sqrt(2), so normalise the distance to be between 0 and 1
                float normalised = minDist / Mathf.Sqrt(2);

                // Pixel colours are bright when normalised is higher and darker when normalised is lower, so
                // a pixel that is very close to a point will be darker than a pixel that is far away from all points.
                texture.SetPixel(x, y, new Color(normalised, normalised, normalised));
            }
        }

        texture.Apply();
        return texture;
    }

}
