/* 
 * WorleyNoise3D.cs extends the 2D cell approach in WorleyNoiseCells.cs to 3D.
 * The grid is now a 3D cube of cells where each cell checks 26 neighbours instead of 8.
 * 
 * The red dot visualiser helped debug a problem in the first implementation which occured
 * when the cell coordinates wrapped around using modulo. This caused the coordinates to wrap
 * to the wrong side of the texture. Taking the difference of the expected coordinate and the
 * wrapped coordinates allowed the coordinates to be offset back to the right position.
 * 
 * The cellular noise concept is explained in:
 * A Cellular Texture Basis Function
 * https://doi.org/10.1145/237170.237267
 * Steven Worley
 */

using UnityEngine;

public class WorleyNoise3D : MonoBehaviour
{
    [Header("Texture Settings")]
    public int textureSize = 256;

    // divides the texture into a cell grid, number specifies how many cells per axis
    public int cellCount = 5;

    public int seed = 30;

    public bool ShowPointCentres = false;

    void Start()
    {
        GenerateTexture();
    }

    void OnValidate()
    {
        // will regenerate the texture when a value is changed in the inspector *only* in play mode.
        // previously when updated in edit mode would bloat memory with textures
        if (Application.isPlaying)
        {
            UpdateTexture();
        }
    }

    void UpdateTexture()
    {
        GenerateTexture();
    }

    // needs to be accessible by slice viewer
    public Texture3D GenerateTexture()
    {

        Random.InitState(seed);

        float cellSize = 1.0f / cellCount;

        Vector3[,,] points = new Vector3[cellCount, cellCount, cellCount];

        for (int x = 0; x < cellCount; x++)
        {
            for (int y = 0; y < cellCount; y++)
            {
                for (int z = 0; z < cellCount; z++)
                {

                    // assign a random coordinate within the bounds of the cell
                    float randomX = (x + Random.value) * cellSize;
                    float randomY = (y + Random.value) * cellSize;
                    float randomZ = (z + Random.value) * cellSize;
                    points[x, y, z] = new Vector3(randomX, randomY, randomZ);
                }
            }
        }

        // total number of pixels in the texture, each needing their own colour definition
        Color[] colours = new Color[textureSize * textureSize * textureSize];
        // creates a 3D texture with 4 channels and no mipmaps (generated not imported so no need for scaled down versions)
        Texture3D texture = new Texture3D(textureSize, textureSize, textureSize, TextureFormat.RGBA32, false);

        for (int pixelX = 0; pixelX < textureSize; pixelX++)
        {
            for (int pixelY = 0; pixelY < textureSize; pixelY++)
            {
                for (int pixelZ = 0; pixelZ < textureSize; pixelZ++)
                {
                    // conversion to normalised range of 0 to 1
                    float u = (float)pixelX / textureSize;
                    float v = (float)pixelY / textureSize;
                    float w = (float)pixelZ / textureSize;
                    Vector3 pixelPosition = new Vector3(u, v, w);

                    // find the cell that the pixel is bounded by. floor rounds down for 0 indexing.
                    int cellX = Mathf.FloorToInt(u * cellCount);
                    int cellY = Mathf.FloorToInt(v * cellCount);
                    int cellZ = Mathf.FloorToInt(w * cellCount);

                    // bound the mininum distance to the maximum possible distance
                    float minDist = float.MaxValue;

                    // iterate through the cell and the 8 cell neighbours
                    for (int offsetX = -1; offsetX <= 1; offsetX++)
                    {
                        for (int offsetY = -1; offsetY <= 1; offsetY++)
                        {
                            for (int offsetZ = -1; offsetZ <= 1; offsetZ++)
                            {
                                // can wrap around the cell coordinates by finding the remainder e.g. 4+1%/5 = 0 -> cell 0
                                int neighbourX = (cellX + offsetX + cellCount) % cellCount;
                                int neighbourY = (cellY + offsetY + cellCount) % cellCount;
                                int neighbourZ = (cellZ + offsetZ + cellCount) % cellCount;

                                // gets the local coordinates of the point in the neighbour cell being evaluated
                                Vector3 neighbourPoint = points[neighbourX, neighbourY, neighbourZ];

                                /* 
                                When cell coordinates wrap around the coordinates are on the wrong side of the texture.
                                This is corrected by calculating where wrapping moved the coordinates to (neighbourX - cellX)
                                and correcting by the difference between that and the offsetX (the direction we want to move to).
                                If no wrapping occurs then neighbourX - cellX = offsetX and the correction is 0. 
                                */

                                Vector3 absolutePoint = new Vector3(
                                    neighbourPoint.x + (offsetX - (neighbourX - cellX)) * cellSize,
                                    neighbourPoint.y + (offsetY - (neighbourY - cellY)) * cellSize,
                                    neighbourPoint.z + (offsetZ - (neighbourZ - cellZ)) * cellSize
                                );

                                float dist = Vector3.Distance(pixelPosition, absolutePoint);

                                if (dist < minDist)
                                {
                                    minDist = dist;
                                }
                            }
                        }
                    }

                    // Maximum distance is when the pixel is in the corner of a cell and the point is in the opposite corner
                    float maxDist = Mathf.Sqrt(3) * cellSize;

                    // normalised to 0-1 range relative to the cell size
                    float normalised = Mathf.Clamp01(minDist / maxDist);

                    // inversion so pixels close to the point are bright (bubble like)
                    float inverted = 1 - normalised;

                    // 3D coordinates need to be converted to a 1D index for the texture array
                    int index = pixelZ * (textureSize * textureSize) + pixelY * textureSize + pixelX;
                    colours[index] = new Color(inverted, inverted, inverted);
                }
            }
        }

        // debugging purposes - shows the point centres as red dots
        if (ShowPointCentres)
        {
            for (int cx = 0; cx < cellCount; cx++)
            {
                for (int cy = 0; cy < cellCount; cy++)
                {
                    for (int cz = 0; cz < cellCount; cz++)
                    {
                        // convert back to exact pixel coordinates
                        int dotX = Mathf.RoundToInt(points[cx, cy, cz].x * textureSize);
                        int dotY = Mathf.RoundToInt(points[cx, cy, cz].y * textureSize);
                        int dotZ = Mathf.RoundToInt(points[cx, cy, cz].z * textureSize);

                        // draw a square of red pixels centred on the point
                        for (int dx = -2; dx <= 2; dx++)
                        {
                            for (int dy = -2; dy <= 2; dy++)
                            {
                                for (int dz = -2; dz <= 2; dz++)
                                {
                                    // clamp to texture edges to avoid dots going out of range
                                    int px = Mathf.Clamp(dotX + dx, 0, textureSize - 1);
                                    int py = Mathf.Clamp(dotY + dy, 0, textureSize - 1);
                                    int pz = Mathf.Clamp(dotZ + dz, 0, textureSize - 1);
                                    // set colours in the 1D array of pixels
                                    int index = pz * (textureSize * textureSize) + py * textureSize + px;
                                    colours[index] = Color.red;
                                }
                            }
                        }
                    }
                }
            }
        }

        texture.SetPixels(colours);

        texture.Apply();
        return texture;
    }

}
