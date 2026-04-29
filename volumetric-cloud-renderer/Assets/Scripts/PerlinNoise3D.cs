/* 
 * PerlinNoise3D.cs generates a 3D Perlin noise texture for the cloud renderer.
 * It produces smooth patterns that have more irregularity than the Worley noise texture.
 * Combining them both gives the clouds a more realistic look by breaking up the orderly
 * circular cells from the Worley noise.
 * 
 * This is based on the Perlin noise algorithm  descibed in:
 * 'An Image Synthesizer'
 * https://dl.acm.org/doi/epdf/10.1145/325334.325247
 * Ken Perlin
 * 
 * The algorithm has since been improved and Ken Perlin discusses the improvement in:
 * 'Improving Noise'
 * https://dl.acm.org/doi/10.1145/566654.566636
 * Ken Perlin
 * 
 * With his Java reference implementation available here:
 * https://cs.nyu.edu/~perlin/noise/
 */

/* Perlins Method:
 * 1. Generate lookup table (Perlin hardcodes values in his example implementation)
 * 2. Scale the voxel position to zoom into the noise
 * 3. Find the cell that the voxel is in
 * 4. Find the position within that cell
 * 5. Smooth the position using the fade function so boundaries arent abrupt
 * 6. Get hash values for each of the 8 corners (3 times each, x, y, z)
 * 7. Based on the hash, calculate the gradient influence for each corner
 * 8. Interpolate the gradient influence between all corners to get the noise value
 * 9. Normalise
 */


using UnityEngine;

public class PerlinNoise3D : MonoBehaviour
{
    [Header("Texture Settings")]
    public int textureSize = 32;

    // a smaller frequency makes the cloud have larger/smoother features
    public float scale = 16f;

    void Start()
    {
        GenerateTexture();
    }

    void OnValidate()
    {
        if (Application.isPlaying)
        {
            GenerateTexture();
        }
    }


    // This approach generally follows the same method of conversion from Perlins initial Java implementation as Stefan Gustavsons breakdown
    // REF: https://www.researchgate.net/publication/216813608_Simplex_noise_demystified

    public Texture3D GenerateTexture()
    {
        // Perlin uses a lookup table instead of generating a random value. It ensures
        // that when sampling the noise at the same position multiple times, we get the same value.
        // Its stored in a buffer thats twice the size to prevent any overflow when indexing with x, y and z coords.
        int[] bufferedPermTable = new int[512];
        int[] permTable = new int[256];

        for (int i = 0; i < 256; i++)
        {
            permTable[i] = i;
        }

        // swap values at each index with a randomly indexed value
        for (int i = 0; i < 256; i++)
        {
            int randomIndex = Mathf.FloorToInt(Random.value * 256);
            int current = permTable[i];
            permTable[i] = permTable[randomIndex];
            permTable[randomIndex] = current;
        }

        for (int i = 0; i < 512; i++)
        {
            // wrap round the permTable so that the first half of bufferedPermTable is identical to the second half
            bufferedPermTable[i] = permTable[i % 256];
        }

        Color[] colours = new Color[textureSize * textureSize * textureSize];
        Texture3D texture = new Texture3D(textureSize, textureSize, textureSize, TextureFormat.RGBA32, false);

        // loop through all of the voxels and get the noise for each one
        for (int pixelX = 0; pixelX < textureSize; pixelX++)
        {
            for (int pixelY = 0; pixelY < textureSize; pixelY++)
            {
                for (int pixelZ = 0; pixelZ < textureSize; pixelZ++)
                {
                    // normalise the coordinates (0-1) to hand to GetNoise which needs to
                    // work for any texture resolution
                    float u = (float)pixelX / textureSize;
                    float v = (float)pixelY / textureSize;
                    float w = (float)pixelZ / textureSize;

                    float noiseValue = GetNoise(u, v, w, bufferedPermTable);

                    // 3D coordinates need to be converted to a 1D index for the texture array
                    int index = pixelZ * (textureSize * textureSize) + pixelY * textureSize + pixelX;
                    colours[index] = new Color(noiseValue, noiseValue, noiseValue);
                }
            }
        }

        texture.SetPixels(colours);
        texture.wrapMode = TextureWrapMode.Repeat;
        texture.Apply();
        return texture;
    }

    // this comes from the improved function in Perlin's improving noise paper.
    public float Fade(float t)
    {
        return 6 * (t * t * t * t * t) - 15 * (t * t * t * t) + 10 * (t * t * t);
    }

    public float Gradient(int hash, float x , float y , float z )
    {
        // gets the remainder of the hash value when divided by 16to cycle through each of the cases.
        // These represent the 12 different gradient directions to the midpoints of each edge in the cube from 
        // the centre of the cube itself.
        switch (hash % 16)
        {
            /* 
             case 0 gradient is (1, 1, 0) so a vector with direction diagonally in x and y with no z
             dot product of gradient and distance x, y, z = (1 * x) + (1 * y) + (0 * z) = x + y
             see Sreenshot: gradient-vectors-perlin.png
             'Breaking down Perlin noise reference implementation'
             Abdelrahman Said
             Available at: 
             https://thewizardapprentice.com/2025/10/27/breaking-down-perlin-noise-reference-implementation/
            */
            case 0: return x + y;
            case 1: return -x + y;
            case 2: return x - y;
            case 3: return -x - y;
            case 4: return x + z;
            case 5: return -x + z;
            case 6: return x - z;
            case 7: return -x - z;
            case 8: return y + z;
            case 9: return -y + z;
            case 10: return y - z;
            case 11: return -y - z;
            case 12: return y + x;
            case 13: return -y + z;
            case 14: return y - x;
            case 15: return -y - z;
            default: return 0;
        }
    }

    public float GetNoise(float x, float y, float z, int[] permTable)
    {
        // take the input coordinates and scale by the frequency set in the slider
        x = x * scale;
        y = y * scale;
        z = z * scale;

        // gets the cubic cell that the position is in (for a unit length cube 1x1x1, 2.7 represents cube 2, hence
        // use Floor)
        int cellX = Mathf.FloorToInt(x) % 256;
        int cellY = Mathf.FloorToInt(y) % 256;
        int cellZ = Mathf.FloorToInt(z) % 256;

        // gets the relative position within the cell (fractional part of the local coordinates)
        float fracX = x - Mathf.Floor(x);
        float fracY = y - Mathf.Floor(y);
        float fracZ = z - Mathf.Floor(z);

        // fade lines for each coordinate
        float fadeX = Fade(fracX);
        float fadeY = Fade(fracY);
        float fadeZ = Fade(fracZ);

        // hash lookup for each of the eight corners.
        // L = Lower = 0, H = Higher = 1. LLL = Corner (0,0,0) etc.
        int LLL = permTable[permTable[permTable[cellX] + cellY] + cellZ];
        int LLH = permTable[permTable[permTable[cellX] + cellY] + cellZ + 1];
        int LHL = permTable[permTable[permTable[cellX] + cellY + 1] + cellZ];
        int HLL = permTable[permTable[permTable[cellX + 1] + cellY] + cellZ];
        int HHH = permTable[permTable[permTable[cellX + 1] + cellY + 1] + cellZ + 1];
        int HHL = permTable[permTable[permTable[cellX + 1] + cellY + 1] + cellZ];
        int HLH = permTable[permTable[permTable[cellX + 1] + cellY] + cellZ + 1];
        int LHH = permTable[permTable[permTable[cellX] + cellY + 1] + cellZ + 1];

        // calculate the gradient influence at each of the 8 corners
        // gradient function takes the hash value and the distance from that corner to the current position
        float gradientLLL = Gradient(LLL, fracX, fracY, fracZ);
        float gradientLLH = Gradient(LLH, fracX, fracY, fracZ - 1);
        float gradientLHL = Gradient(LHL, fracX, fracY - 1, fracZ);
        float gradientHLL = Gradient(HLL, fracX - 1, fracY, fracZ);
        float gradientHHH = Gradient(HHH, fracX - 1, fracY - 1, fracZ - 1);
        float gradientHHL = Gradient(HHL, fracX - 1, fracY - 1, fracZ);
        float gradientHLH = Gradient(HLH, fracX - 1, fracY, fracZ - 1);
        float gradientLHH = Gradient(LHH, fracX, fracY - 1, fracZ - 1);

        // to interpolate between the 8 corner gradients, we need to do it in 3 stages
        // 1. blend along x between corner pairs
        // 2. blend those along y
        // 3. blend that along z
        // This incorporates the fade lines for smoothness around boundaries for Perlins improved noise
        float x1 = Mathf.Lerp(gradientLLL, gradientHLL, fadeX);
        float x2 = Mathf.Lerp(gradientLHL, gradientHHL, fadeX);
        float x3 = Mathf.Lerp(gradientLLH, gradientHLH, fadeX);
        float x4 = Mathf.Lerp(gradientLHH, gradientHHH, fadeX);

        float y1 = Mathf.Lerp(x1, x2, fadeY);
        float y2 = Mathf.Lerp(x3, x4, fadeY);

        float result = Mathf.Lerp(y1, y2, fadeZ);

        // result is between -1 and +1 which our texture cant handle.
        // need to shift the entire range by 1 and then divide by 2 to keep the value
        // between 0 and 1.
        return (result + 1) / 2.0f;
    }

}
