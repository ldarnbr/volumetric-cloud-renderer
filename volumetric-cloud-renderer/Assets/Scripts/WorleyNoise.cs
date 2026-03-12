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

                // 
                for (int tileX = -1; tileX <= 1; tileX++)
                {
                    for (int tileY = -1; tileY <= 1; tileY++)
                    {
                        // need to calculate the distance between the pixel and all the points to find which is closest
                        foreach (Vector2 point in points)
                        {
                            // shift each of the points into the grid of tiles around the pixel so the pixel
                            // can evaluate distance to points in the neighbouring tiles as well as the tile it is in
                            Vector2 tiledPoint = point + new Vector2(tileX, tileY);
                            float dist = Vector2.Distance(pixelPos, tiledPoint);
                            // stores the minimum distance
                            if (dist < minDist)
                            {
                                minDist = dist;
                            }
                        }
                    }
                }
     

                // maximum distance for one 1x1 square is sqrt(2), so normalise the distance to be between 0 and 1
                float normalised = minDist / Mathf.Sqrt(2);

                // invert to make the texture darker further from points
                float inverted = 1 - normalised;

                // make the texture more contrasted by raising the inverted value to the power 3.
                float contrasted = Mathf.Pow(inverted, 3);


                // Pixel colours are bright when contrasted is lower and darker when contrasted is higher, so
                // a pixel that is very close to a point will be lighter than a pixel that is far away from all points.
                texture.SetPixel(x, y, new Color(contrasted, contrasted, contrasted));
            }
        }
        // allow texture to tile across the object
        texture.wrapMode = TextureWrapMode.Repeat;
        texture.Apply();
        return texture;
    }

}
