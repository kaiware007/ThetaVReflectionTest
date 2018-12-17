using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AutoRotateAround : MonoBehaviour {

    public Vector3 center;
    public Vector3 axis = Vector3.up;
    public float rotSpeed = 100;

    void Update()
    {
        transform.RotateAround(center, axis, rotSpeed * Time.deltaTime);
    }
}
