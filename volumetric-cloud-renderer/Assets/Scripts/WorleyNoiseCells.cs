using UnityEngine;

public class WorleyNoiseCells : MonoBehaviour
{
    [Header("Texture Settings")]
    public int textureSize = 256;

    // divides the texture into a cell grid, number specifies how many cells per axis
    public int cellCount = 5;

    public int seed = 30;

    void Start()
    {
        // attach the texture to the material and wrap it so it tiles across the surface
        Texture2D texture = GenerateTexture();
        texture.wrapMode = TextureWrapMode.Repeat;
        GetComponent<Renderer>().material.mainTexture = texture;
    }

    Texture2D GenerateTexture()
    {
        Texture2D texture = new Texture2D(textureSize, textureSize);

        Random.InitState(seed);

        Vector2[,] points = new Vector2[cellCount, cellCount];

        for (int x = 0; x < cellCount; x++)
        {
            for (int y = 0; y < cellCount; y++)
            {
                // each cell is a 1/cellCount fraction of the space
                float size = 1.0f / cellCount;

                // assign a random coordinate within the bounds of the cell
                float randomY = (x + Random.value) * size;
                float randomX = (y + Random.value) * size;
                points[x, y] = new Vector2(randomX, randomY);
            }
        }

        for (int pixelX = 0; pixelX < textureSize; pixelX++)
        {
            for (int pixelY = 0; pixelY < textureSize; pixelY++)
            {
                // conversion to normalised range of 0 to 1
                float u = (float)pixelX / textureSize;
                float v = (float)pixelY / textureSize;
                Vector2 pixelPosition = new Vector2(u, v);

                // find the cell that the pixel is bounded by. floor rounds down for 0 indexing.
                int cellX = Mathf.FloorToInt(u * cellCount);
                int cellY = Mathf.FloorToInt(v * cellCount);

                // bound the mininum distance to the maximum possible distance
                float minDist = float.MaxValue;

                // iterate through the cell and the 8 cell neighbours
                for (int offsetX = -1; offsetX <=1; offsetX++)
                {
                    for (int offsetY = -1; offsetY <= 1; offsetY++)
                    {
                        // can wrap around the cell coordinates by finding the remainder e.g. 5+1%/5 = 1 -> cell 1
                        int neighbourX = (cellX + offsetX + cellCount) % cellCount;
                        int neighbourY = (cellY + offsetY + cellCount) % cellCount;

                        // gets the local coordinates of the point in the neighbour cell being evaluated
                        Vector2 neighbourPoint = points[neighbourX, neighbourY];

                        Vector2 cellOffset = new Vector2(offsetX, offsetY) / cellCount;

                        // gets the tiled position of the neighbour point
                        Vector2 tiledPoint = neighbourPoint + cellOffset;

                        float dist = Vector2.Distance(pixelPosition, tiledPoint);
                        if (dist < minDist)
                        {
                            minDist = dist;
                        }
                    }
                }

                float cellSize = 1.0f / cellCount;

                // Maximum distance is when the pixel is in the corner of a cell and the point is in the opposite corner
                float maxDist = Mathf.Sqrt(2) * cellSize;

                // normalised to 0-1 range relative to the cell size
                float normalised = Mathf.Clamp01(minDist / maxDist);

                // inversion so pixels close to the point are bright (bubble like)
                float inverted = 1 - normalised;

                // more contrast by raising to the power of 3
                float contrasted = Mathf.Pow(Mathf.Clamp01(inverted), 3);

                // pixel brightness is set in greyscale
                texture.SetPixel(pixelX, pixelY, new Color(contrasted, contrasted, contrasted));
            }
        }
        texture.Apply();
        return texture;
    }

}
