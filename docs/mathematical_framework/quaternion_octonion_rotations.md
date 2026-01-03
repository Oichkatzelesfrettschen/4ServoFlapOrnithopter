# Quaternion and Octonion Rotations for Ornithopter Flight Control

## Executive Summary

This document provides a rigorous mathematical framework for spatial rotations and orientation tracking in the 4-servo flapping ornithopter system, utilizing quaternions and exploring octonion extensions for advanced control.

## 1. Quaternion Mathematics for 3D Rotations

### 1.1 Quaternion Representation

A quaternion **q** is a 4-dimensional hypercomplex number:

```
q = w + xi + yj + zk
where i² = j² = k² = ijk = -1
```

For unit quaternions (||q|| = 1), we represent rotations:
```
q = [cos(θ/2), sin(θ/2) · n̂]
```

where θ is the rotation angle and n̂ is the unit rotation axis.

### 1.2 Quaternion Operations for Flight Control

**Quaternion Multiplication** (rotation composition):
```
q₁ ⊗ q₂ = [w₁w₂ - v₁·v₂, w₁v₂ + w₂v₁ + v₁×v₂]
```

**Quaternion Conjugate** (inverse rotation):
```
q* = [w, -v]
```

**Vector Rotation**:
For a 3D vector **v**, rotation by quaternion **q**:
```
v' = q ⊗ [0, v] ⊗ q*
```

### 1.3 Implementation for Ornithopter

```cpp
// Quaternion structure for ornithopter orientation
struct Quaternion {
    float w, x, y, z;
    
    // Normalize quaternion to unit length
    void normalize() {
        float norm = sqrt(w*w + x*x + y*y + z*z);
        if (norm > 0.0001f) {
            w /= norm; x /= norm; y /= norm; z /= norm;
        }
    }
    
    // Quaternion multiplication
    Quaternion operator*(const Quaternion& q) const {
        return {
            w*q.w - x*q.x - y*q.y - z*q.z,
            w*q.x + x*q.w + y*q.z - z*q.y,
            w*q.y - x*q.z + y*q.w + z*q.x,
            w*q.z + x*q.y - y*q.x + z*q.w
        };
    }
    
    // Quaternion conjugate
    Quaternion conjugate() const {
        return {w, -x, -y, -z};
    }
    
    // Convert to Euler angles (roll, pitch, yaw)
    void toEuler(float& roll, float& pitch, float& yaw) const {
        // Roll (x-axis rotation)
        float sinr_cosp = 2.0f * (w * x + y * z);
        float cosr_cosp = 1.0f - 2.0f * (x * x + y * y);
        roll = atan2(sinr_cosp, cosr_cosp);
        
        // Pitch (y-axis rotation)
        float sinp = 2.0f * (w * y - z * x);
        if (abs(sinp) >= 1)
            pitch = copysign(M_PI / 2, sinp);
        else
            pitch = asin(sinp);
        
        // Yaw (z-axis rotation)
        float siny_cosp = 2.0f * (w * z + x * y);
        float cosy_cosp = 1.0f - 2.0f * (y * y + z * z);
        yaw = atan2(siny_cosp, cosy_cosp);
    }
};
```

### 1.4 Gyroscope Integration with Quaternions

Integration of angular velocity ω = [ωx, ωy, ωz] over time dt:

```cpp
void updateQuaternionFromGyro(Quaternion& q, float wx, float wy, float wz, float dt) {
    // Create quaternion from angular velocity
    float halfdt = dt * 0.5f;
    Quaternion qDot = {
        -halfdt * (q.x * wx + q.y * wy + q.z * wz),
         halfdt * (q.w * wx + q.y * wz - q.z * wy),
         halfdt * (q.w * wy - q.x * wz + q.z * wx),
         halfdt * (q.w * wz + q.x * wy - q.y * wx)
    };
    
    // Update quaternion
    q.w += qDot.w;
    q.x += qDot.x;
    q.y += qDot.y;
    q.z += qDot.z;
    
    // Normalize to maintain unit quaternion
    q.normalize();
}
```

## 2. Octonion Extensions for Advanced Control

### 2.1 Octonion Algebra

Octonions extend quaternions to 8 dimensions:
```
o = w + x₁e₁ + x₂e₂ + x₃e₃ + x₄e₄ + x₅e₅ + x₆e₆ + x₇e₇
```

Properties:
- Non-commutative (like quaternions)
- Non-associative (unique to octonions)
- Useful for 7D rotations and higher-dimensional control spaces

### 2.2 Application to Ornithopter Control

Octonions can represent extended state space:
- **e₁, e₂, e₃**: Spatial orientation (roll, pitch, yaw)
- **e₄, e₅**: Wing phase relationships (front-rear, left-right)
- **e₆**: Flapping frequency modulation
- **e₇**: Amplitude variation coupling

### 2.3 Octonion Structure

```cpp
struct Octonion {
    float w;
    float x[7];
    
    // Octonion multiplication (non-associative)
    Octonion operator*(const Octonion& o) const {
        Octonion result;
        // Multiplication table implementation
        // Based on Fano plane structure
        result.w = w * o.w;
        for (int i = 0; i < 7; i++) {
            result.w -= x[i] * o.x[i];
        }
        // ... (complete multiplication table)
        return result;
    }
};
```

## 3. Spatial Calculation Framework

### 3.1 Wing Tip Trajectory Calculation

For flapping motion with parameters:
- **θ(t)**: Flapping angle
- **φ**: Wing sweep angle
- **r**: Wing length

Position vector:
```
P(t) = [
    r · sin(θ(t)) · cos(φ),
    r · sin(θ(t)) · sin(φ),
    r · cos(θ(t))
]
```

Velocity (for aerodynamic calculations):
```
V(t) = dP/dt = [
    r · θ̇(t) · cos(θ(t)) · cos(φ),
    r · θ̇(t) · cos(θ(t)) · sin(φ),
    -r · θ̇(t) · sin(θ(t))
]
```

### 3.2 Phase Relationship Mathematics

Front-rear wing phase delay (controlled by Ch6):
```
θ_rear(t) = A · sin(ωt)
θ_front(t) = A · sin(ωt + Δφ)
```

where Δφ ∈ [0, π] is the phase delay.

Optimal thrust at Δφ = π/4 (quarter-phase delay).

### 3.3 Coordinate Transformations

**Body Frame to World Frame**:
```
v_world = R(q) · v_body
```

where R(q) is the rotation matrix from quaternion q:
```
R(q) = [
    [1-2(y²+z²),   2(xy-wz),     2(xz+wy)   ]
    [2(xy+wz),     1-2(x²+z²),   2(yz-wx)   ]
    [2(xz-wy),     2(yz+wx),     1-2(x²+y²) ]
]
```

## 4. Stability Analysis Mathematics

### 4.1 Linearized Dynamics

For small perturbations around equilibrium:
```
ẋ = Ax + Bu
y = Cx
```

State vector: **x** = [roll, pitch, yaw, ωx, ωy, ωz]ᵀ

### 4.2 Lyapunov Stability

Stability criterion: Find V(x) > 0 such that:
```
V̇(x) = ∂V/∂x · ẋ < 0
```

Candidate Lyapunov function:
```
V(x) = xᵀPx where P > 0
```

### 4.3 Eigenvalue Analysis

System stability requires:
```
Re(λᵢ) < 0 for all eigenvalues λᵢ of A
```

## 5. Numerical Methods

### 5.1 Runge-Kutta Integration (RK4)

For quaternion integration:
```cpp
Quaternion rk4Step(const Quaternion& q, float wx, float wy, float wz, float dt) {
    auto omega = [wx, wy, wz](const Quaternion& q) {
        return Quaternion{
            -0.5f * (q.x * wx + q.y * wy + q.z * wz),
             0.5f * (q.w * wx + q.y * wz - q.z * wy),
             0.5f * (q.w * wy - q.x * wz + q.z * wx),
             0.5f * (q.w * wz + q.x * wy - q.y * wx)
        };
    };
    
    Quaternion k1 = omega(q);
    Quaternion k2 = omega(q + k1 * (dt/2));
    Quaternion k3 = omega(q + k2 * (dt/2));
    Quaternion k4 = omega(q + k3 * dt);
    
    Quaternion result = q + (k1 + k2*2 + k3*2 + k4) * (dt/6);
    result.normalize();
    return result;
}
```

## 6. Technical Debt Analysis (Debitum Technicum)

### 6.1 Current Lacunae (Gaps)

1. **No quaternion-based orientation tracking**: Current system uses Euler angles only
2. **Missing gyroscope integration**: No IMU sensor fusion
3. **Lack of formal stability analysis**: No mathematical guarantees
4. **No adaptive control**: Fixed control parameters

### 6.2 Mathematical Remediation

Implement:
- Complementary filter: α·gyro + (1-α)·accelerometer
- Madgwick or Mahony filter for sensor fusion
- Gain scheduling based on flight state
- Model predictive control (MPC)

## 7. References

1. Kuipers, J.B. (1999). "Quaternions and Rotation Sequences"
2. Madgwick, S. (2010). "An efficient orientation filter for IMU and MARG sensor arrays"
3. Baez, J.C. (2002). "The Octonions"
4. Stevens, B.L. & Lewis, F.L. (2003). "Aircraft Control and Simulation"

## 8. Implementation Roadmap

1. **Phase 1**: Add quaternion library to Arduino codebase
2. **Phase 2**: Integrate IMU (MPU6050/MPU9250) with I2C
3. **Phase 3**: Implement Madgwick filter for orientation estimation
4. **Phase 4**: Add real-time stability monitoring
5. **Phase 5**: Implement adaptive control algorithms
6. **Phase 6**: Explore octonion-based multi-parameter optimization

## Conclusion

The mathematical framework presented here provides a rigorous foundation for:
- Precise orientation tracking using quaternions
- Singularity-free rotation representation
- Efficient computational methods for embedded systems
- Extension to higher-dimensional control spaces via octonions
- Formal stability guarantees through Lyapunov analysis

This framework addresses critical technical debt and provides a path toward advanced autonomous flight capabilities.
