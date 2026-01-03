# Machine Learning and Self-Awareness Algorithms for Ornithopter Control

## Executive Summary

This document presents comprehensive machine learning frameworks, including Multi-Layer Perceptron (MLP) architectures and situational awareness algorithms, for adaptive and autonomous ornithopter flight control.

## 1. Multi-Layer Perceptron (MLP) Architecture

### 1.1 Neural Network Fundamentals

#### 1.1.1 MLP Structure

```
Input Layer → Hidden Layer(s) → Output Layer
```

For ornithopter control:
- **Input**: [roll, pitch, yaw, ωx, ωy, ωz, altitude, velocity, wind, ...]
- **Hidden**: Typically 2-3 layers with 16-64 neurons each
- **Output**: [servo_cmd1, servo_cmd2, servo_cmd3, servo_cmd4]

#### 1.1.2 Forward Propagation

Layer computation:
```
a^[l] = g(W^[l] · a^[l-1] + b^[l])
```

where:
- W^[l] = weight matrix for layer l
- b^[l] = bias vector
- g(·) = activation function
- a^[l] = layer activation

#### 1.1.3 Activation Functions

**ReLU** (Rectified Linear Unit):
```
g(z) = max(0, z)
g'(z) = 1 if z > 0, else 0
```

**Tanh** (hyperbolic tangent):
```
g(z) = tanh(z) = (e^z - e^-z)/(e^z + e^-z)
g'(z) = 1 - tanh²(z)
```

**Sigmoid**:
```
g(z) = 1/(1 + e^-z)
g'(z) = g(z) · (1 - g(z))
```

### 1.2 Training Algorithm

#### 1.2.1 Loss Function

Mean Squared Error for control outputs:
```
L = (1/m) · Σ ||y_pred - y_true||²
```

Huber loss (robust to outliers):
```
L_δ(y, ŷ) = {
    ½(y - ŷ)²           if |y - ŷ| ≤ δ
    δ|y - ŷ| - ½δ²      otherwise
}
```

#### 1.2.2 Backpropagation

Gradient computation:
```
∂L/∂W^[l] = ∂L/∂a^[l] · ∂a^[l]/∂z^[l] · ∂z^[l]/∂W^[l]
```

Chain rule through layers:
```
δ^[l] = (W^[l+1])^T · δ^[l+1] ⊙ g'(z^[l])
```

Weight update:
```
W^[l] := W^[l] - α · ∂L/∂W^[l]
```

#### 1.2.3 Optimization Algorithms

**Stochastic Gradient Descent (SGD)**:
```
θ := θ - α · ∇L(θ; x_i, y_i)
```

**Adam Optimizer**:
```
m_t = β₁ · m_{t-1} + (1-β₁) · g_t
v_t = β₂ · v_{t-1} + (1-β₂) · g_t²
θ := θ - α · m_t / (√v_t + ε)
```

where:
- m_t = first moment (mean)
- v_t = second moment (variance)
- β₁ ≈ 0.9, β₂ ≈ 0.999

### 1.3 MLP Implementation for Arduino

#### 1.3.1 Lightweight Neural Network

```cpp
class SimpleNN {
private:
    static const int INPUT_SIZE = 12;
    static const int HIDDEN_SIZE = 16;
    static const int OUTPUT_SIZE = 4;
    
    float W1[HIDDEN_SIZE][INPUT_SIZE];
    float b1[HIDDEN_SIZE];
    float W2[OUTPUT_SIZE][HIDDEN_SIZE];
    float b2[OUTPUT_SIZE];
    
    float hidden[HIDDEN_SIZE];
    float output[OUTPUT_SIZE];
    
    float relu(float x) {
        return x > 0 ? x : 0;
    }
    
    float tanh_approx(float x) {
        // Fast approximation: tanh(x) ≈ x / (1 + |x|)
        return x / (1 + abs(x));
    }

public:
    void forward(const float* input) {
        // Hidden layer
        for (int i = 0; i < HIDDEN_SIZE; i++) {
            float sum = b1[i];
            for (int j = 0; j < INPUT_SIZE; j++) {
                sum += W1[i][j] * input[j];
            }
            hidden[i] = relu(sum);
        }
        
        // Output layer
        for (int i = 0; i < OUTPUT_SIZE; i++) {
            float sum = b2[i];
            for (int j = 0; j < HIDDEN_SIZE; j++) {
                sum += W2[i][j] * hidden[j];
            }
            output[i] = tanh_approx(sum);
        }
    }
    
    const float* getOutput() {
        return output;
    }
    
    void loadWeights(const float* weights, int size) {
        // Load pre-trained weights from PROGMEM or EEPROM
        int idx = 0;
        for (int i = 0; i < HIDDEN_SIZE; i++) {
            for (int j = 0; j < INPUT_SIZE; j++) {
                W1[i][j] = weights[idx++];
            }
        }
        // ... load b1, W2, b2 ...
    }
};
```

#### 1.3.2 Input Normalization

```cpp
struct NormParams {
    float mean[12];
    float std[12];
};

void normalizeInput(float* input, const NormParams& params, int size) {
    for (int i = 0; i < size; i++) {
        input[i] = (input[i] - params.mean[i]) / params.std[i];
    }
}
```

#### 1.3.3 Output Denormalization

```cpp
void denormalizeOutput(float* output, int size) {
    // Map [-1, 1] to servo range [1000, 2000] μs
    for (int i = 0; i < size; i++) {
        output[i] = 1500 + output[i] * 500;
        output[i] = constrain(output[i], 1000, 2000);
    }
}
```

## 2. Reinforcement Learning for Adaptive Control

### 2.1 Q-Learning Framework

#### 2.1.1 State-Action-Reward Model

State space **S**:
```
s = [orientation, angular_rates, altitude, velocity, battery_level]
```

Action space **A**:
```
a = [Δflap_freq, Δflap_amp, Δphase_delay, Δtrim]
```

Reward function **R**:
```
R(s, a) = w₁·altitude_error + w₂·stability + w₃·energy_efficiency
```

#### 2.1.2 Q-Value Update

```
Q(s, a) := Q(s, a) + α·[r + γ·max_{a'}Q(s', a') - Q(s, a)]
```

where:
- α = learning rate (0.01-0.1)
- γ = discount factor (0.9-0.99)
- r = immediate reward

#### 2.1.3 ε-Greedy Exploration

```
a = {
    random action           with probability ε
    argmax_a Q(s, a)       with probability 1-ε
}
```

Decay schedule:
```
ε(t) = ε_min + (ε_max - ε_min)·e^(-λt)
```

### 2.2 Policy Gradient Methods

#### 2.2.1 Policy Representation

Stochastic policy:
```
π(a|s; θ) = P(action a | state s; parameters θ)
```

For continuous actions (servo commands):
```
a ~ N(μ(s; θ), σ²)
```

where μ is neural network output.

#### 2.2.2 REINFORCE Algorithm

Policy gradient:
```
∇_θ J(θ) = E[∇_θ log π(a|s; θ) · Q(s, a)]
```

Update rule:
```
θ := θ + α·∇_θ log π(a|s; θ)·G_t
```

where G_t is discounted return.

#### 2.2.3 Actor-Critic Architecture

**Actor** (policy network):
```
π(a|s) → servo commands
```

**Critic** (value network):
```
V(s) → expected return
```

Advantage function:
```
A(s, a) = Q(s, a) - V(s)
```

## 3. Situational Awareness Algorithms

### 3.1 State Estimation

#### 3.1.1 Extended Kalman Filter (EKF)

Full state vector:
```
x = [position, velocity, orientation, angular_rates, wind, biases]ᵀ
```

Prediction step:
```
x̂_{k|k-1} = f(x̂_{k-1|k-1}, u_k)
P_{k|k-1} = F_k P_{k-1|k-1} F_k^T + Q_k
```

Update step:
```
K_k = P_{k|k-1} H_k^T (H_k P_{k|k-1} H_k^T + R_k)^{-1}
x̂_{k|k} = x̂_{k|k-1} + K_k(z_k - h(x̂_{k|k-1}))
P_{k|k} = (I - K_k H_k) P_{k|k-1}
```

#### 3.1.2 Unscented Kalman Filter (UKF)

Sigma point generation:
```
χ_0 = x̂
χ_i = x̂ + (√((n+λ)P))_i    for i = 1, ..., n
χ_i = x̂ - (√((n+λ)P))_{i-n}  for i = n+1, ..., 2n
```

Transform through nonlinear function:
```
γ_i = f(χ_i)
```

Predicted mean:
```
x̂^- = Σ w_i^m · γ_i
```

### 3.2 Anomaly Detection

#### 3.2.1 Statistical Process Control

Control limits:
```
UCL = μ + 3σ  (Upper Control Limit)
LCL = μ - 3σ  (Lower Control Limit)
```

CUSUM (Cumulative Sum):
```
S_h[k] = max(0, S_h[k-1] + x[k] - (μ + K))
S_l[k] = max(0, S_l[k-1] - x[k] + (μ - K))
```

Alarm if S_h > H or S_l > H.

#### 3.2.2 Mahalanobis Distance

Multivariate outlier detection:
```
D²(x) = (x - μ)^T Σ^{-1} (x - μ)
```

Threshold:
```
D²_threshold = χ²_{α, n}  (chi-squared distribution)
```

#### 3.2.3 One-Class SVM

For novelty detection:
```
f(x) = sgn(Σ α_i K(x_i, x) - ρ)
```

where K is kernel function (e.g., RBF):
```
K(x, x') = exp(-||x - x'||² / (2σ²))
```

### 3.3 Failure Mode Detection

#### 3.3.1 Servo Health Monitoring

Current sensing:
```
I_servo = V_sense / R_sense
```

Power consumption:
```
P = V_supply · I_servo
```

Fault conditions:
```
if (I_servo > I_max) → overload
if (I_servo < I_min AND commanded_motion > 0) → mechanical jam
if (temp > T_max) → thermal failure
```

#### 3.3.2 Sensor Plausibility Checks

Accelerometer magnitude:
```
|a| should be ≈ g during steady flight
```

Gyro-accel consistency:
```
α_gyro vs. α_accel (low-pass filtered) should agree
```

Altitude-pressure consistency:
```
dh/dt from pressure vs. vertical_velocity from accel integration
```

#### 3.3.3 Flight Envelope Protection

Safe operating boundaries:
```
|roll| < roll_max
|pitch| < pitch_max
altitude > altitude_min
airspeed > stall_speed
```

Soft limits with gradual authority reduction:
```
authority = {
    1.0                          if x < x_soft
    1 - (x - x_soft)/(x_hard - x_soft)  if x_soft ≤ x < x_hard
    0.0                          if x ≥ x_hard
}
```

## 4. Adaptive Control Algorithms

### 4.1 Model Reference Adaptive Control (MRAC)

#### 4.1.1 Reference Model

Desired dynamics:
```
ẋ_m = A_m x_m + B_m r
```

where r is reference command.

#### 4.1.2 Adaptation Law

MIT rule:
```
θ̇ = -γ · e · φ
```

where:
- e = x - x_m (tracking error)
- φ = sensitivity derivative
- γ = adaptation gain

Lyapunov-based (stable):
```
θ̇ = -Γ · P · B · e
```

#### 4.1.3 Implementation

```cpp
class MRACController {
private:
    float K_ff;  // Feedforward gain
    float K_fb;  // Feedback gain
    float gamma; // Adaptation rate
    
public:
    void update(float x, float x_m, float r, float dt) {
        float e = x - x_m;
        
        // Adaptive law
        K_ff += gamma * e * r * dt;
        K_fb += gamma * e * x * dt;
        
        // Constrain gains for stability
        K_ff = constrain(K_ff, K_ff_min, K_ff_max);
        K_fb = constrain(K_fb, K_fb_min, K_fb_max);
    }
    
    float getControl(float x, float r) {
        return K_ff * r + K_fb * x;
    }
};
```

### 4.2 Gain Scheduling

#### 4.2.1 Operating Point Classification

Flight regimes:
```
regime = {
    HOVER      if V < V_hover
    CRUISE     if V_hover ≤ V < V_cruise
    HIGH_SPEED if V ≥ V_cruise
}
```

#### 4.2.2 Interpolated Gains

```cpp
float interpolateGain(float V, float V1, float V2, float K1, float K2) {
    float alpha = (V - V1) / (V2 - V1);
    alpha = constrain(alpha, 0, 1);
    return K1 + alpha * (K2 - K1);
}
```

#### 4.2.3 Smooth Transitions

Exponential smoothing:
```
K_smoothed[k] = α·K_scheduled + (1-α)·K_smoothed[k-1]
```

### 4.3 Online Parameter Estimation

#### 4.3.1 Recursive Least Squares (RLS)

System identification:
```
y[k] = θ^T φ[k] + e[k]
```

Update equations:
```
K[k] = P[k-1] φ[k] / (λ + φ[k]^T P[k-1] φ[k])
θ[k] = θ[k-1] + K[k] (y[k] - φ[k]^T θ[k-1])
P[k] = (I - K[k] φ[k]^T) P[k-1] / λ
```

where λ is forgetting factor (0.95-0.99).

#### 4.3.2 Mass Estimation

Battery depletion changes mass:
```
m_est = F_thrust / a_measured
```

Filtered estimate:
```
m̂[k] = α_m · m_raw[k] + (1-α_m) · m̂[k-1]
```

#### 4.3.3 Aerodynamic Coefficient Estimation

Lift coefficient:
```
C_L,est = 2·L / (ρ·V²·S)
```

Drag coefficient:
```
C_D,est = 2·D / (ρ·V²·S)
```

## 5. Bayesian Inference for Situational Awareness

### 5.1 Bayesian State Estimation

#### 5.1.1 Bayes' Rule

Posterior probability:
```
P(x|z) = P(z|x) · P(x) / P(z)
```

Recursive Bayesian estimation:
```
P(x_k|z_{1:k}) ∝ P(z_k|x_k) · ∫ P(x_k|x_{k-1}) P(x_{k-1}|z_{1:k-1}) dx_{k-1}
```

#### 5.1.2 Particle Filter

Particle representation:
```
P(x) ≈ Σ w_i δ(x - x_i)
```

Resampling:
```
Importance weight: w_i ∝ P(z|x_i)
Resample particles proportional to weights
```

#### 5.1.3 Grid-Based Filter

Discretize state space:
```
belief[i][j][k] = P(x = grid_point[i][j][k] | measurements)
```

Update:
```
belief' = normalize(likelihood × prediction)
```

### 5.2 Contextual Awareness

#### 5.2.1 Flight Mode Estimation

Hidden Markov Model (HMM):
```
States: {TAKEOFF, CRUISE, TURN, LANDING}
```

Transition probabilities:
```
P(s_k|s_{k-1}) = A[s_{k-1}][s_k]
```

Observation model:
```
P(z_k|s_k) = emission probability
```

Viterbi algorithm for most likely sequence.

#### 5.2.2 Terrain Classification

Features:
```
f = [altitude_variance, pressure_gradient, GPS_fix_quality]
```

Bayesian classification:
```
P(terrain=mountain|f) ∝ P(f|mountain) · P(mountain)
```

#### 5.2.3 Weather State Estimation

Turbulence index:
```
TI = σ_accel / |a_mean|
```

Wind change detection:
```
Δwind = ||V_wind[k] - V_wind[k-n]||
```

Precipitation probability (from humidity + pressure):
```
P(rain) = sigmoid(w^T [RH, dp/dt] + b)
```

## 6. Energy-Aware Decision Making

### 6.1 Battery State Estimation

#### 6.1.1 Coulomb Counting

State of Charge (SOC):
```
SOC[k] = SOC[0] - ∫ I(t) dt / C_nominal
```

Discrete update:
```
SOC[k] = SOC[k-1] - I[k]·Δt / (3600·C_Ah)
```

#### 6.1.2 Voltage-Based Estimation

Open-circuit voltage model:
```
OCV = f(SOC)  (empirical LiPo curve)
```

With internal resistance:
```
V_terminal = OCV - I·R_internal
```

Extended Kalman Filter for joint SOC-resistance estimation.

#### 6.1.3 Remaining Flight Time

Power consumption model:
```
P(V, f_flap, α) = P_base + k_V·V² + k_f·f_flap² + k_α·α²
```

Time to empty:
```
t_remaining = E_remaining / P_avg
```

### 6.2 Optimal Trajectory Planning

#### 6.2.1 Energy-Optimal Path

Cost function:
```
J = ∫ (E(t) + w_time) dt
```

subject to:
```
ẋ = f(x, u)  (dynamics)
g(x) ≥ 0     (constraints)
```

#### 6.2.2 Dijkstra's Algorithm

For discrete waypoint graph:
```
cost[node] = min(cost[prev] + edge_cost[prev→node])
```

Edge cost includes:
```
cost = distance/groundspeed + energy_penalty + risk_factor
```

#### 6.2.3 Rapidly-Exploring Random Tree (RRT)

Sampling-based planning:
```
1. Sample random state x_rand
2. Find nearest node x_near in tree
3. Steer towards x_rand: x_new = steer(x_near, x_rand)
4. If collision-free, add x_new to tree
5. Repeat until goal reached
```

## 7. Real-Time Implementation Considerations

### 7.1 Computational Budget

Typical Arduino Pro Mini @ 16 MHz:
- ~16 MIPS (million instructions per second)
- Limited RAM (2 KB)
- Limited flash (32 KB)

Processing allocation (10 ms cycle):
```
Sensor reading:    2 ms
Sensor fusion:     2 ms
ML inference:      3 ms
Control compute:   2 ms
Servo update:      1 ms
```

### 7.2 Model Compression

#### 7.2.1 Weight Quantization

Float32 → Int8:
```
w_int8 = round(w_float32 / scale) + zero_point
```

Reduces memory by 4×, increases speed by 2-4×.

#### 7.2.2 Pruning

Remove small weights:
```
if |w| < threshold:
    w = 0
```

Sparse matrix storage for efficiency.

#### 7.2.3 Knowledge Distillation

Train small "student" network to mimic large "teacher" network:
```
L = α·L_CE(y_student, y_true) + (1-α)·L_KD(y_student, y_teacher)
```

### 7.3 Fixed-Point Neural Networks

```cpp
typedef int16_t fixed_t;  // Q7.8 format

fixed_t float_to_fixed(float x) {
    return (fixed_t)(x * 256);
}

fixed_t fixed_mul(fixed_t a, fixed_t b) {
    return (a * b) >> 8;
}
```

## 8. Validation and Testing

### 8.1 Simulation Environment

Physics simulation:
- Flight dynamics model
- Sensor models (with noise)
- Environmental disturbances

Software-in-the-loop (SIL):
- Run control code on PC
- Interface with simulator

Hardware-in-the-loop (HIL):
- Run control code on actual Arduino
- Simulate sensors via serial/I2C

### 8.2 Performance Metrics

**Tracking error**:
```
RMSE = √(Σ(x_ref - x_actual)² / N)
```

**Stability margin**:
```
gain_margin, phase_margin from frequency response
```

**Energy efficiency**:
```
η = distance_traveled / energy_consumed
```

### 8.3 Safety Verification

Formal verification methods:
- Reachability analysis
- Barrier certificates
- Contract-based design

## 9. Technical Debt and Future Work

### 9.1 Current Limitations

1. **No online learning**: Parameters fixed after training
2. **Limited state estimation**: Basic sensor fusion only
3. **No failure handling**: No graceful degradation
4. **Lack of vision**: No obstacle avoidance

### 9.2 Recommended Enhancements

**Short-term**:
- Implement Madgwick filter + MLP for stabilization
- Add battery monitoring with SOC estimation
- Develop servo health monitoring

**Medium-term**:
- Online parameter adaptation (RLS)
- Terrain-aware flight modes
- Predictive maintenance

**Long-term**:
- Vision-based navigation (camera + CNN)
- Multi-agent coordination
- End-to-end reinforcement learning

## 10. References

1. Goodfellow, I. et al. (2016). "Deep Learning"
2. Sutton, R. & Barto, A. (2018). "Reinforcement Learning: An Introduction"
3. Thrun, S. et al. (2005). "Probabilistic Robotics"
4. Lavretsky, E. & Wise, K. (2013). "Robust Adaptive Control"
5. Bishop, C. (2006). "Pattern Recognition and Machine Learning"

## Conclusion

This comprehensive framework provides:
- **MLP architectures** for nonlinear control mapping
- **Reinforcement learning** for adaptive behavior
- **Situational awareness** through Bayesian inference and anomaly detection
- **Energy-aware planning** for extended flight time
- **Real-time implementation** strategies for embedded systems

Integration of these algorithms will enable autonomous, adaptive, and robust ornithopter flight with self-awareness and intelligent decision-making capabilities.
