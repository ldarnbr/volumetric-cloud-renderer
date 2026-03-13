using UnityEngine;

public class SliceViewer : MonoBehaviour
{
    public WorleyNoise3D noiseGenerator;

    [Range(0f, 1f)]
    public float sliceDepth = 0f;


    // Start is called before the first frame update
    void Start()
    {
        UpdateSlice();
    }

    void OnValidate()
    {
        if (Application.isPlaying)
        {
            UpdateSlice();
        }
    }

    // Update is called once per frame
    void UpdateSlice()
    {
        if (noiseGenerator != null)
        {
            Texture3D texture3D = noiseGenerator.GenerateTexture();
            // using a cube, so width, height and depth are the same
            int size = texture3D.width;

            // need to convert the slice depth to an integer for a Z pixel index
            int sliceZ = Mathf.Clamp(Mathf.RoundToInt(sliceDepth * (size - 1)), 0, size - 1);

            // create a 2D texture for the slice
            Texture2D slice = new Texture2D(size, size);

            // gets all the pixels at the z coordinate
            Color[] colours = texture3D.GetPixels();
            Color[] sliceColours = new Color[size * size];

            for (int x = 0; x < size; x++)
            {
                for ( int y = 0; y < size; y++)
                {
                    int index = sliceZ * (size * size) + y * size + x;
                    sliceColours[y * size + x] = colours[index];
                }
            }

            slice.SetPixels(sliceColours);
            slice.Apply();

            // show the new slice on the material of the object it's applied to
            GetComponent<Renderer>().material.mainTexture = slice;

        } else
        {
            return;
        }

    }
}
