# Sensor Integration and Hardware Mathematics

## Executive Summary

This document provides comprehensive mathematical frameworks for integrating on-board sensors (pressure, humidity, wind speed, gyroscopes, accelerometers) with the ornithopter control system, including calibration, data fusion, and real-time processing algorithms.

## 1. Inertial Measurement Unit (IMU) Integration

### 1.1 Gyroscope Mathematics

#### 1.1.1 MEMS Gyroscope Model

Output model:
```
ω_measured = S · ω_true + b + n
```

where:
- S = scale factor matrix (3×3)
- b = bias vector (slowly varying)
- n = white noise ~ N(0, σ²_n)

#### 1.1.2 Bias Estimation

Allan variance method for characterizing gyro noise:
```
σ²(τ) = E[(ω_k+1 - ω_k)²] / 2
```

Temperature-compensated bias:
```
b(T) = b₀ + k_T · (T - T₀)
```

#### 1.1.3 Angular Rate Integration

Trapezoid rule for orientation update:
```
θ(t + Δt) = θ(t) + (ω(t) + ω(t+Δt))/2 · Δt
```

With quaternion representation:
```
q(t + Δt) = q(t) + 0.5 · Ω(ω_avg) · q(t) · Δt
```

where:
```
Ω(ω) = [  0   -ωx  -ωy  -ωz ]
        [ ωx    0    ωz  -ωy ]
        [ ωy  -ωz    0    ωx ]
        [ ωz   ωy  -ωx    0  ]
```

### 1.2 Accelerometer Mathematics

#### 1.2.1 Measurement Model

```
a_measured = R(q) · (a_body - g) + ba + na
```

where:
- R(q) = rotation matrix from world to body frame
- g = [0, 0, 9.81] m/s² (gravity)
- ba = accelerometer bias
- na = measurement noise

#### 1.2.2 Tilt Estimation from Accelerometer

For static or quasi-static conditions:
```
roll = atan2(ay, az)
pitch = atan2(-ax, √(ay² + az²))
```

Valid when |a| ≈ g (no significant body acceleration).

#### 1.2.3 Vibration Filtering

High-frequency vibration from servos requires filtering:

**Low-pass filter** (1st order):
```
a_filtered[k] = α · a_measured[k] + (1-α) · a_filtered[k-1]
```

where α = Δt / (Δt + τ), τ = filter time constant.

**Moving average**:
```
a_filtered = (1/N) · Σ(a_measured[k-i]) for i=0 to N-1
```

### 1.3 Magnetometer Integration

#### 1.3.1 Measurement Model

```
m_measured = R(q) · m_earth + bm + dm + nm
```

where:
- m_earth = Earth's magnetic field in world frame
- bm = hard iron distortion (constant offset)
- dm = soft iron distortion (scale/non-orthogonality)
- nm = measurement noise

#### 1.3.2 Calibration

Hard iron calibration:
```
m_calibrated = m_measured - bm
```

where bm is center of measured ellipsoid:
```
bm = (m_max + m_min) / 2
```

Soft iron calibration:
```
m_corrected = W · (m_measured - bm)
```

where W is correction matrix obtained from ellipsoid fitting.

#### 1.3.3 Yaw from Magnetometer

Magnetic heading:
```
ψ_mag = atan2(-my', mx')
```

where (mx', my') are horizontal components in earth frame:
```
[mx']   [cos(θ)    0      sin(θ)  ] [mx]
[my'] = [sin(φ)sin(θ) cos(φ) -sin(φ)cos(θ)] [my]
[mz']   [-cos(φ)sin(θ) sin(φ) cos(φ)cos(θ)] [mz]
```

## 2. Pressure Sensor Integration

### 2.1 Barometric Altimetry

#### 2.1.1 Pressure-Altitude Relationship

International Standard Atmosphere (ISA):
```
h = (T₀/L) · [1 - (p/p₀)^(R·L/(g₀·M))]
```

where:
- T₀ = 288.15 K (sea level temperature)
- L = 0.0065 K/m (temperature lapse rate)
- p₀ = 101325 Pa (sea level pressure)
- R = 8.31447 J/(mol·K) (gas constant)
- g₀ = 9.80665 m/s²
- M = 0.0289644 kg/mol (molar mass of air)

Simplified for h < 11 km:
```
h ≈ 44330 · [1 - (p/p₀)^0.1903]
```

#### 2.1.2 Temperature Compensation

Pressure sensors exhibit temperature drift:
```
p_corrected = p_measured · (1 + α_T · (T - T_ref))
```

where α_T is temperature coefficient (typically 0.01-0.05%/°C).

#### 2.1.3 Vertical Velocity Estimation

Numerical differentiation:
```
v_z = dh/dt ≈ (h[k] - h[k-1]) / Δt
```

Noise amplification requires filtering:

**α-β filter**:
```
h_filtered[k] = h_predicted[k] + α · (h_measured[k] - h_predicted[k])
v_filtered[k] = v_predicted[k] + β · (h_measured[k] - h_predicted[k]) / Δt

h_predicted[k+1] = h_filtered[k] + v_filtered[k] · Δt
v_predicted[k+1] = v_filtered[k]
```

### 2.2 Differential Pressure for Airspeed

#### 2.2.1 Pitot-Static System

Bernoulli's equation:
```
p_total = p_static + ½ρV²
```

Airspeed:
```
V = √(2(p_total - p_static) / ρ)
```

#### 2.2.2 Calibration Corrections

Indicated airspeed (IAS) to true airspeed (TAS):
```
TAS = IAS · √(ρ₀/ρ)
```

Position error correction:
```
p_static,true = p_static,measured + Δp_position(α, β)
```

#### 2.2.3 Dynamic Pressure Sensing

For ornithopter scale, hot-wire anemometer may be more suitable:

King's law:
```
E² = A + B · V^n
```

where E is voltage, A and B are calibration constants, n ≈ 0.45-0.5.

## 3. Environmental Sensors

### 3.1 Humidity Sensing

#### 3.1.1 Capacitive Humidity Sensor Model

Capacitance-humidity relationship:
```
C = C₀ · (1 + k_H · RH)
```

where:
- C₀ = dry capacitance
- k_H = humidity sensitivity coefficient
- RH = relative humidity (%)

#### 3.1.2 Humidity Effect on Air Density

Virtual temperature:
```
T_v = T / (1 - e/p · (1 - ε))
```

where:
- e = vapor pressure
- ε = 0.622 (ratio of molecular masses)

Humid air density:
```
ρ_humid = (p / (R_specific · T_v))
```

Vapor pressure from RH:
```
e = (RH/100) · e_sat(T)
```

where e_sat is saturation vapor pressure (Clausius-Clapeyron):
```
e_sat = 611.21 · exp(17.502 · (T-273.15) / (T-32.18))
```

#### 3.1.3 Performance Correction

Lift and thrust scale with density:
```
L_humid = L_dry · (ρ_humid / ρ_dry)
T_humid = T_dry · (ρ_humid / ρ_dry)
```

### 3.2 Temperature Sensing

#### 3.2.1 Thermistor Model

Steinhart-Hart equation:
```
1/T = A + B·ln(R) + C·(ln(R))³
```

where R is thermistor resistance, A, B, C are calibration coefficients.

Simplified (β-parameter):
```
R = R₀ · exp(β · (1/T - 1/T₀))
```

#### 3.2.2 Multi-Point Temperature Monitoring

Servo motor temperatures: T_servo[i], i=1..4
Battery temperature: T_battery
Ambient temperature: T_ambient

Thermal warning thresholds:
```
T_servo,max = 80°C (typical servo rating)
T_battery,max = 60°C (LiPo safety limit)
```

#### 3.2.3 Thermal Runaway Detection

Rate of temperature rise:
```
dT/dt = (T[k] - T[k-1]) / Δt
```

Warning condition:
```
if (dT/dt > threshold) AND (T > T_warn):
    trigger_thermal_protection()
```

### 3.3 Wind Speed and Direction

#### 3.3.1 Ground-Relative Wind Estimation

From GPS and airspeed:
```
V_wind = V_ground - V_air
```

where both are 3D vectors.

Wind speed:
```
W = |V_wind|
```

Wind direction:
```
ψ_wind = atan2(V_wind,east, V_wind,north)
```

#### 3.3.2 Gust Detection

Statistical analysis over window:
```
σ_V = √(Σ(V[i] - V_mean)² / N)
```

Gust threshold:
```
V_gust = V_mean + k · σ_V
```

where k = 2-3 (confidence level).

#### 3.3.3 Turbulence Intensity

Dryden turbulence model:
```
Φ_u(Ω) = σ_u² · (2L_u / π) / (1 + (L_u·Ω)²)
```

where:
- σ_u = turbulence intensity
- L_u = turbulence length scale
- Ω = spatial frequency

## 4. Sensor Fusion Algorithms

### 4.1 Complementary Filter

#### 4.1.1 Basic Complementary Filter

Combines gyro (high-frequency accurate) with accelerometer (low-frequency accurate):

```
α[k] = α_gyro · (α[k-1] + ω_gyro · Δt) + (1-α_gyro) · α_accel
```

where α_gyro ≈ 0.98 (high-pass on gyro, low-pass on accel).

#### 4.1.2 Full Quaternion Complementary Filter

```
q[k] = α_cf · q_gyro[k] + (1-α_cf) · q_accel[k]
q[k].normalize()
```

### 4.2 Kalman Filter

#### 4.2.1 Extended Kalman Filter (EKF) for Orientation

State vector:
```
x = [q₀, q₁, q₂, q₃, bx, by, bz]ᵀ
```

State prediction:
```
x[k|k-1] = f(x[k-1], u[k])
P[k|k-1] = F · P[k-1] · Fᵀ + Q
```

Measurement update:
```
K = P[k|k-1] · Hᵀ · (H · P[k|k-1] · Hᵀ + R)⁻¹
x[k] = x[k|k-1] + K · (z[k] - h(x[k|k-1]))
P[k] = (I - K · H) · P[k|k-1]
```

#### 4.2.2 Process Model

Quaternion kinematics:
```
q̇ = 0.5 · Ω(ω - b) · q
ḃ = 0  (random walk)
```

Discretization:
```
q[k] = q[k-1] + 0.5 · Ω(ω[k] - b[k-1]) · q[k-1] · Δt
b[k] = b[k-1] + w_b[k]
```

#### 4.2.3 Measurement Model

From accelerometer:
```
z_acc = R(q)ᵀ · [0, 0, -g] + v_acc
```

From magnetometer:
```
z_mag = R(q)ᵀ · m_earth + v_mag
```

### 4.3 Madgwick Filter

#### 4.3.1 Gradient Descent Orientation Filter

Objective function (alignment of sensors with expected directions):
```
f(q) = [R(q)ᵀ·g - a_measured]
        [R(q)ᵀ·m - m_measured]
```

Gradient:
```
∇f = Jᵀ · f
```

Update:
```
q̇_ω = 0.5 · Ω(ω) · q
q̇_∇ = -β · (∇f / |∇f|)
q̇ = q̇_ω + q̇_∇
```

where β is step size (tuning parameter).

#### 4.3.2 Adaptive Gain

```
β = √(3/4) · ω_err,mean
```

where ω_err is estimated gyro error.

#### 4.3.3 Implementation

```cpp
void madgwickUpdate(Quaternion& q, float ax, float ay, float az,
                     float gx, float gy, float gz, float dt) {
    // Normalize accelerometer
    float norm = sqrt(ax*ax + ay*ay + az*az);
    ax /= norm; ay /= norm; az /= norm;
    
    // Objective function (accelerometer only, simplified)
    float f1 = 2*(q.x*q.z - q.w*q.y) - ax;
    float f2 = 2*(q.w*q.x + q.y*q.z) - ay;
    float f3 = 2*(0.5f - q.x*q.x - q.y*q.y) - az;
    
    // Jacobian
    float j11 = -2*q.y, j12 = 2*q.z, j13 = -2*q.w, j14 = 2*q.x;
    float j21 = 2*q.x,  j22 = 2*q.w, j23 = 2*q.z,  j24 = 2*q.y;
    float j31 = 0,      j32 = -4*q.x, j33 = -4*q.y, j34 = 0;
    
    // Gradient
    float grad_w = j11*f1 + j21*f2 + j31*f3;
    float grad_x = j12*f1 + j22*f2 + j32*f3;
    float grad_y = j13*f1 + j23*f2 + j33*f3;
    float grad_z = j14*f1 + j24*f2 + j34*f3;
    
    norm = sqrt(grad_w*grad_w + grad_x*grad_x + grad_y*grad_y + grad_z*grad_z);
    grad_w /= norm; grad_x /= norm; grad_y /= norm; grad_z /= norm;
    
    // Integrate
    float beta = 0.1f; // tuning parameter
    q.w += (0.5f*(-q.x*gx - q.y*gy - q.z*gz) - beta*grad_w) * dt;
    q.x += (0.5f*(q.w*gx + q.y*gz - q.z*gy) - beta*grad_x) * dt;
    q.y += (0.5f*(q.w*gy - q.x*gz + q.z*gx) - beta*grad_y) * dt;
    q.z += (0.5f*(q.w*gz + q.x*gy - q.y*gx) - beta*grad_z) * dt;
    
    q.normalize();
}
```

## 5. Hardware Interface Specifications

### 5.1 I2C Communication

#### 5.1.1 MPU6050/MPU9250 IMU

Standard I2C addresses:
- MPU6050: 0x68 or 0x69
- AK8963 (magnetometer in MPU9250): 0x0C

Initialization sequence:
```cpp
// Wake up MPU6050
writeByte(MPU6050_ADDR, PWR_MGMT_1, 0x00);

// Configure gyro range (±250°/s)
writeByte(MPU6050_ADDR, GYRO_CONFIG, 0x00);

// Configure accel range (±2g)
writeByte(MPU6050_ADDR, ACCEL_CONFIG, 0x00);

// Set sample rate divider (1kHz / (1 + div))
writeByte(MPU6050_ADDR, SMPLRT_DIV, 0x07); // 125 Hz
```

#### 5.1.2 BMP280/BME280 Pressure/Humidity

I2C address: 0x76 or 0x77

Oversampling settings:
```cpp
// Pressure oversampling ×16
// Temperature oversampling ×2
// Humidity oversampling ×1
uint8_t ctrl_meas = (2 << 5) | (5 << 2) | 0x03;
writeByte(BME280_ADDR, CTRL_MEAS, ctrl_meas);
```

Compensation formulas (from datasheet):
```
var1 = ((adc_T >> 3) - (dig_T1 << 1)) * dig_T2 >> 11;
var2 = (((adc_T >> 4) - dig_T1) * ((adc_T >> 4) - dig_T1) >> 12) * dig_T3 >> 14;
t_fine = var1 + var2;
T = (t_fine * 5 + 128) >> 8; // in 0.01°C
```

### 5.2 Analog-to-Digital Conversion (ADC)

#### 5.2.1 Arduino ADC Specifications

- Resolution: 10-bit (0-1023)
- Reference voltage: 5V (or 3.3V)
- Conversion time: ~100 μs

Voltage calculation:
```
V = (ADC_value / 1023.0) * V_ref
```

#### 5.2.2 Oversampling for Effective Resolution

To gain n bits of resolution, oversample by 4ⁿ:
```cpp
uint32_t sum = 0;
for (int i = 0; i < 256; i++) { // 256 = 4^4 for 4 extra bits
    sum += analogRead(pin);
}
uint16_t result = sum >> 4; // 14-bit result
```

#### 5.2.3 Anti-Aliasing

For ADC sampling rate f_s, anti-alias filter cutoff:
```
f_cutoff < f_s / 2  (Nyquist criterion)
```

RC low-pass filter:
```
f_cutoff = 1 / (2π · R · C)
```

### 5.3 SPI Communication

For high-speed sensors (e.g., high-rate IMU):

Clock rates:
- Standard: 4 MHz
- High-speed: 8-20 MHz

SPI modes (clock polarity/phase):
- Mode 0: CPOL=0, CPHA=0 (most common for IMUs)
- Mode 3: CPOL=1, CPHA=1

## 6. Real-Time Processing Architecture

### 6.1 Interrupt-Driven Sampling

Timer interrupt for fixed sample rate:
```cpp
ISR(TIMER1_COMPA_vect) {
    dataReady = true;
}

void setup() {
    // Set timer for 100 Hz
    TCCR1A = 0;
    TCCR1B = (1 << WGM12) | (1 << CS11) | (1 << CS10); // CTC, prescaler 64
    OCR1A = 2499; // (16MHz / 64 / 100Hz) - 1
    TIMSK1 = (1 << OCIE1A);
}
```

### 6.2 Data Pipeline

```
Sensors → Raw Data → Calibration → Filtering → Sensor Fusion → State Estimate → Control
```

Processing budget (100 Hz update):
- 10 ms total period
- Sensor read: < 2 ms
- Calibration: < 0.5 ms
- Fusion: < 2 ms
- Control computation: < 3 ms
- Servo update: < 1 ms
- Margin: 1.5 ms

### 6.3 Fixed-Point Arithmetic

For faster computation on Arduino:

Float to fixed-point (Q16.16 format):
```cpp
int32_t floatToFixed(float x) {
    return (int32_t)(x * 65536.0f);
}

float fixedToFloat(int32_t x) {
    return (float)x / 65536.0f;
}
```

Fixed-point multiplication:
```cpp
int32_t fixedMul(int32_t a, int32_t b) {
    return (int64_t)a * b >> 16;
}
```

## 7. Calibration Procedures

### 7.1 Gyroscope Calibration

Six-position static calibration:
1. Place ornithopter in 6 orientations (+X, -X, +Y, -Y, +Z, -Z)
2. Record gyro readings for 10 seconds each
3. Average to obtain bias for each axis
4. Compute scale factors from known rotations

### 7.2 Accelerometer Calibration

Twelve-point tumble test:
1. Orient +X, -X, +Y, -Y, +Z, -Z axis aligned with gravity
2. Record measurements
3. Solve for bias and scale:
```
a_calibrated = S · (a_measured - b)
```

where S is 3×3 scale matrix.

### 7.3 Magnetometer Calibration

Figure-8 motion:
1. Rotate ornithopter in all orientations
2. Record (mx, my, mz) forming ellipsoid
3. Fit ellipsoid: x'ᵀAx' + b'ᵀx' + c = 0
4. Extract hard/soft iron corrections

## 8. Fault Detection and Diagnostics

### 8.1 Sensor Health Monitoring

Range checks:
```cpp
bool isSensorHealthy(float value, float min, float max) {
    return (value >= min) && (value <= max) && !isnan(value) && !isinf(value);
}
```

### 8.2 Redundancy and Voting

For critical measurements, use triple modular redundancy:
```cpp
float median(float a, float b, float c) {
    if ((a >= b && a <= c) || (a >= c && a <= b)) return a;
    if ((b >= a && b <= c) || (b >= c && b <= a)) return b;
    return c;
}
```

### 8.3 Watchdog Timer

Detect software hangs:
```cpp
#include <avr/wdt.h>

void setup() {
    wdt_enable(WDTO_250MS); // 250ms watchdog
}

void loop() {
    wdt_reset(); // Pet the watchdog
    // ... main code ...
}
```

## 9. Technical Debt and Recommendations

### 9.1 Current Gaps

1. **No IMU integration**: Critical for autonomous stabilization
2. **Missing environmental sensing**: Cannot adapt to conditions
3. **No sensor fusion**: Individual sensor limitations not addressed
4. **Lack of calibration routines**: Drift and bias uncompensated

### 9.2 Recommended Sensor Suite

Minimum viable instrumentation:
- **MPU6050**: 6-DOF IMU (gyro + accel)
- **BMP280**: Barometric pressure/temperature
- **Optional**: DHT22 (humidity), GPS module

### 9.3 Implementation Priority

1. **High**: MPU6050 + Madgwick filter
2. **Medium**: BMP280 for altitude hold
3. **Low**: Magnetometer (if GPS not available)
4. **Future**: Optical flow, lidar for obstacle avoidance

## 10. References

1. Madgwick, S. (2010). "An efficient orientation filter for IMU and MARG sensor arrays"
2. Mahony, R. et al. (2008). "Nonlinear complementary filters on SO(3)"
3. InvenSense (2013). "MPU-6000/MPU-6050 Product Specification"
4. Bosch Sensortec (2018). "BMP280 Digital Pressure Sensor Datasheet"

## Appendix: Hardware Compatibility Matrix

| Sensor | Interface | Voltage | Current | Update Rate | Compatible Boards |
|--------|-----------|---------|---------|-------------|-------------------|
| MPU6050 | I2C | 3.3V | 3.9 mA | 1 kHz | Arduino Pro Mini (3.3V) |
| MPU9250 | I2C/SPI | 3.3V | 4.9 mA | 1 kHz | Arduino Pro Mini (3.3V) |
| BMP280 | I2C/SPI | 3.3V | 2.7 µA | 157 Hz | Arduino Pro Mini (any) |
| BME280 | I2C/SPI | 3.3V | 3.6 µA | 157 Hz | Arduino Pro Mini (any) |
| HMC5883L | I2C | 3.3V | 100 µA | 75 Hz | Arduino Pro Mini (3.3V) |

**Note**: Arduino Pro Mini 5V requires level shifters for 3.3V sensors.
