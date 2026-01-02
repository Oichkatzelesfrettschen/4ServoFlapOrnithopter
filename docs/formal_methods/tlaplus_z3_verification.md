# Formal Methods: TLA+ and Z3 for Ornithopter Safety Verification

## Executive Summary

This document presents formal verification methodologies using TLA+ (Temporal Logic of Actions) for specifying and verifying concurrent system behavior, and Z3 (SMT solver) for constraint solving and theorem proving, applied to the ornithopter control system.

## 1. TLA+ Specification Language

### 1.1 Introduction to TLA+

TLA+ (Temporal Logic of Actions Plus) is a formal specification language for describing and reasoning about concurrent and distributed systems.

**Key concepts**:
- **States**: Assignments of values to variables
- **Behaviors**: Sequences of states
- **Actions**: State transitions
- **Temporal formulas**: Properties over behaviors

### 1.2 Basic TLA+ Syntax

#### 1.2.1 Module Structure

```tla
---- MODULE OrnithopterControl ----
EXTENDS Naturals, Reals, Sequences

CONSTANTS
    MaxServoPos,     \* Maximum servo position (microseconds)
    MinServoPos,     \* Minimum servo position
    MaxRollAngle,    \* Maximum safe roll angle (degrees)
    MaxPitchAngle,   \* Maximum safe pitch angle
    MinAltitude,     \* Minimum safe altitude (meters)
    MaxThrottle      \* Maximum throttle value

VARIABLES
    servoPos,        \* Current servo positions [4]
    orientation,     \* Current orientation [roll, pitch, yaw]
    altitude,        \* Current altitude (meters)
    velocity,        \* Current velocity vector [vx, vy, vz]
    batteryLevel,    \* Battery state of charge (0-100%)
    flightMode,      \* Current flight mode
    sensorData       \* Sensor readings
====
```

#### 1.2.2 State Predicates

```tla
\* Type invariant - defines valid states
TypeOK ==
    /\ servoPos \in [1..4 -> MinServoPos..MaxServoPos]
    /\ orientation.roll \in -180..180
    /\ orientation.pitch \in -90..90
    /\ orientation.yaw \in -180..180
    /\ altitude >= 0
    /\ batteryLevel \in 0..100
    /\ flightMode \in {"IDLE", "TAKEOFF", "CRUISE", "TURN", "LANDING", "EMERGENCY"}
```

### 1.3 Ornithopter Control System Specification

#### 1.3.1 Complete TLA+ Specification

```tla
---- MODULE OrnithopterFlightControl ----
EXTENDS Naturals, Reals, Sequences, TLC

CONSTANTS
    MinServoPos,     \* 1000 microseconds
    MaxServoPos,     \* 2000 microseconds
    MaxRollAngle,    \* 45 degrees
    MaxPitchAngle,   \* 30 degrees
    MinAltitude,     \* 0.5 meters (ground clearance)
    CriticalBattery, \* 20% battery level
    MaxFlapFreq,     \* 7 Hz
    MinFlapFreq      \* 3 Hz

VARIABLES
    servoCmd,        \* Commanded servo positions [FL, FR, RL, RR]
    orientation,     \* Current orientation [roll, pitch, yaw]
    angularRate,     \* Angular velocities [wx, wy, wz]
    altitude,        \* Current altitude
    verticalVel,     \* Vertical velocity
    batterySOC,      \* State of charge
    flightMode,      \* Operating mode
    sensorStatus,    \* Health status of sensors
    flapFreq,        \* Flapping frequency
    flapPhase,       \* Phase relationship front/rear wings
    controlEnabled,  \* Master enable flag
    errorState       \* Error flags

vars == <<servoCmd, orientation, angularRate, altitude, verticalVel, 
          batterySOC, flightMode, sensorStatus, flapFreq, flapPhase,
          controlEnabled, errorState>>

\* ============ Type Invariants ============

TypeInvariant ==
    /\ servoCmd \in [{"FL", "FR", "RL", "RR"} -> MinServoPos..MaxServoPos]
    /\ orientation.roll \in Real
    /\ orientation.pitch \in Real
    /\ orientation.yaw \in Real
    /\ angularRate.wx \in Real
    /\ angularRate.wy \in Real
    /\ angularRate.wz \in Real
    /\ altitude \in Real
    /\ altitude >= 0
    /\ verticalVel \in Real
    /\ batterySOC \in 0..100
    /\ flightMode \in {"IDLE", "PREFLIGHT", "TAKEOFF", "CRUISE", 
                       "TURN", "LANDING", "EMERGENCY", "FAILSAFE"}
    /\ sensorStatus \in [{"IMU", "BARO", "MAG"} -> {"OK", "DEGRADED", "FAILED"}]
    /\ flapFreq \in MinFlapFreq..MaxFlapFreq
    /\ flapPhase \in 0..180
    /\ controlEnabled \in BOOLEAN
    /\ errorState \in SUBSET {"LOW_BATTERY", "SENSOR_FAILURE", "ATTITUDE_ERROR",
                               "ALTITUDE_ERROR", "SERVO_FAILURE"}

\* ============ Safety Properties ============

\* Safety: Attitude must stay within limits during flight
AttitudeSafety ==
    (flightMode \in {"CRUISE", "TURN"}) =>
        /\ orientation.roll \in -MaxRollAngle..MaxRollAngle
        /\ orientation.pitch \in -MaxPitchAngle..MaxPitchAngle

\* Safety: Altitude must stay above minimum
AltitudeSafety ==
    (flightMode \in {"CRUISE", "TURN", "LANDING"}) =>
        altitude >= MinAltitude

\* Safety: Servos must stay within physical limits
ServoSafety ==
    \A servo \in DOMAIN servoCmd:
        servoCmd[servo] \in MinServoPos..MaxServoPos

\* Safety: Battery must trigger failsafe when critical
BatterySafety ==
    (batterySOC < CriticalBattery) =>
        (flightMode = "FAILSAFE" \/ flightMode = "LANDING")

\* Safety: Sensor failures must be handled
SensorSafety ==
    (\E sensor \in DOMAIN sensorStatus: sensorStatus[sensor] = "FAILED") =>
        ("SENSOR_FAILURE" \in errorState)

\* Overall safety invariant
Safety ==
    /\ TypeInvariant
    /\ AttitudeSafety
    /\ AltitudeSafety
    /\ ServoSafety
    /\ BatterySafety
    /\ SensorSafety

\* ============ Initial State ============

Init ==
    /\ servoCmd = [s \in {"FL", "FR", "RL", "RR"} |-> 1500]
    /\ orientation = [roll |-> 0, pitch |-> 0, yaw |-> 0]
    /\ angularRate = [wx |-> 0, wy |-> 0, wz |-> 0]
    /\ altitude = 0
    /\ verticalVel = 0
    /\ batterySOC = 100
    /\ flightMode = "IDLE"
    /\ sensorStatus = [s \in {"IMU", "BARO", "MAG"} |-> "OK"]
    /\ flapFreq = 5
    /\ flapPhase = 45
    /\ controlEnabled = FALSE
    /\ errorState = {}

\* ============ State Transitions ============

\* Enable control system
EnableControl ==
    /\ flightMode = "IDLE"
    /\ batterySOC > CriticalBattery
    /\ \A sensor \in DOMAIN sensorStatus: sensorStatus[sensor] # "FAILED"
    /\ controlEnabled' = TRUE
    /\ flightMode' = "PREFLIGHT"
    /\ UNCHANGED <<servoCmd, orientation, angularRate, altitude, verticalVel,
                   batterySOC, sensorStatus, flapFreq, flapPhase, errorState>>

\* Takeoff sequence
Takeoff ==
    /\ flightMode = "PREFLIGHT"
    /\ controlEnabled = TRUE
    /\ altitude < MinAltitude
    /\ flightMode' = "TAKEOFF"
    /\ flapFreq' \in (flapFreq..MaxFlapFreq)
    /\ altitude' > altitude
    /\ UNCHANGED <<servoCmd, orientation, angularRate, verticalVel,
                   batterySOC, sensorStatus, flapPhase, controlEnabled, errorState>>

\* Transition to cruise
EnterCruise ==
    /\ flightMode = "TAKEOFF"
    /\ altitude >= MinAltitude * 3
    /\ orientation.roll \in -10..10
    /\ orientation.pitch \in -10..10
    /\ flightMode' = "CRUISE"
    /\ UNCHANGED <<servoCmd, orientation, angularRate, altitude, verticalVel,
                   batterySOC, sensorStatus, flapFreq, flapPhase, controlEnabled, errorState>>

\* Execute turn maneuver
ExecuteTurn ==
    /\ flightMode = "CRUISE"
    /\ flightMode' = "TURN"
    /\ servoCmd' \in [DOMAIN servoCmd -> MinServoPos..MaxServoPos]
    /\ orientation' \in [roll: -MaxRollAngle..MaxRollAngle,
                         pitch: -MaxPitchAngle..MaxPitchAngle,
                         yaw: Real]
    /\ UNCHANGED <<angularRate, altitude, verticalVel, batterySOC, sensorStatus,
                   flapFreq, flapPhase, controlEnabled, errorState>>

\* Return from turn to cruise
ReturnToCruise ==
    /\ flightMode = "TURN"
    /\ orientation.roll \in -5..5
    /\ flightMode' = "CRUISE"
    /\ UNCHANGED <<servoCmd, orientation, angularRate, altitude, verticalVel,
                   batterySOC, sensorStatus, flapFreq, flapPhase, controlEnabled, errorState>>

\* Initiate landing
InitiateLanding ==
    /\ flightMode \in {"CRUISE", "TURN"}
    /\ batterySOC > CriticalBattery
    /\ flightMode' = "LANDING"
    /\ flapFreq' \in MinFlapFreq..flapFreq
    /\ UNCHANGED <<servoCmd, orientation, angularRate, altitude, verticalVel,
                   batterySOC, sensorStatus, flapPhase, controlEnabled, errorState>>

\* Complete landing
CompleteLanding ==
    /\ flightMode = "LANDING"
    /\ altitude <= MinAltitude
    /\ verticalVel <= 0.5  \* Gentle touchdown
    /\ flightMode' = "IDLE"
    /\ controlEnabled' = FALSE
    /\ UNCHANGED <<servoCmd, orientation, angularRate, altitude, verticalVel,
                   batterySOC, sensorStatus, flapFreq, flapPhase, errorState>>

\* Battery discharge (continuous background process)
BatteryDischarge ==
    /\ batterySOC > 0
    /\ batterySOC' = IF batterySOC > 1 THEN batterySOC - 1 ELSE 0
    /\ (batterySOC' < CriticalBattery) => 
        errorState' = errorState \union {"LOW_BATTERY"}
    /\ UNCHANGED <<servoCmd, orientation, angularRate, altitude, verticalVel,
                   flightMode, sensorStatus, flapFreq, flapPhase, controlEnabled>>

\* Sensor failure injection (for testing)
SensorFailure ==
    /\ \E sensor \in DOMAIN sensorStatus:
        /\ sensorStatus[sensor] # "FAILED"
        /\ sensorStatus' = [sensorStatus EXCEPT ![sensor] = "FAILED"]
    /\ errorState' = errorState \union {"SENSOR_FAILURE"}
    /\ UNCHANGED <<servoCmd, orientation, angularRate, altitude, verticalVel,
                   batterySOC, flightMode, flapFreq, flapPhase, controlEnabled>>

\* Enter failsafe mode
EnterFailsafe ==
    /\ flightMode # "FAILSAFE"
    /\ (batterySOC < CriticalBattery \/ errorState # {})
    /\ flightMode' = "FAILSAFE"
    /\ servoCmd' = [s \in DOMAIN servoCmd |-> 1500]  \* Center servos
    /\ flapFreq' = MinFlapFreq  \* Minimum power consumption
    /\ UNCHANGED <<orientation, angularRate, altitude, verticalVel, batterySOC,
                   sensorStatus, flapPhase, controlEnabled, errorState>>

\* ============ Next State Relation ============

Next ==
    \/ EnableControl
    \/ Takeoff
    \/ EnterCruise
    \/ ExecuteTurn
    \/ ReturnToCruise
    \/ InitiateLanding
    \/ CompleteLanding
    \/ BatteryDischarge
    \/ SensorFailure
    \/ EnterFailsafe

\* ============ Specification ============

Spec == Init /\ [][Next]_vars

\* ============ Liveness Properties ============

\* Eventually land if battery is low
EventuallyLand ==
    (batterySOC < CriticalBattery) ~> (flightMode = "IDLE")

\* If in failsafe, eventually land or idle
FailsafeResolution ==
    (flightMode = "FAILSAFE") ~> (flightMode \in {"LANDING", "IDLE"})

\* ============ Theorems ============

\* Prove that safety is maintained
THEOREM Spec => []Safety

\* Prove that system eventually lands when battery is critical
THEOREM Spec => EventuallyLand

====
```

#### 1.3.2 Model Checking Configuration

```
\* TLC configuration file: OrnithopterFlightControl.cfg

SPECIFICATION Spec

CONSTANTS
    MinServoPos = 1000
    MaxServoPos = 2000
    MaxRollAngle = 45
    MaxPitchAngle = 30
    MinAltitude = 0.5
    CriticalBattery = 20
    MaxFlapFreq = 7
    MinFlapFreq = 3

INVARIANTS
    TypeInvariant
    Safety
    AttitudeSafety
    AltitudeSafety
    ServoSafety
    BatterySafety

PROPERTIES
    EventuallyLand
    FailsafeResolution
```

## 2. Z3 SMT Solver Integration

### 2.1 Introduction to Z3

Z3 is a high-performance Satisfiability Modulo Theories (SMT) solver from Microsoft Research. It can solve constraints over:
- Integers and reals
- Bit-vectors
- Arrays
- Algebraic datatypes
- Quantifiers

### 2.2 Servo Control Verification with Z3

#### 2.2.1 Basic Constraint Checking

```python
from z3 import *

# Define servo command variables
servo_FL = Int('servo_FL')
servo_FR = Int('servo_FR')
servo_RL = Int('servo_RL')
servo_RR = Int('servo_RR')

# Physical constraints
MIN_SERVO = 1000
MAX_SERVO = 2000

s = Solver()

# Add range constraints
s.add(servo_FL >= MIN_SERVO, servo_FL <= MAX_SERVO)
s.add(servo_FR >= MIN_SERVO, servo_FR <= MAX_SERVO)
s.add(servo_RL >= MIN_SERVO, servo_RL <= MAX_SERVO)
s.add(servo_RR >= MIN_SERVO, servo_RR <= MAX_SERVO)

# Control law: symmetric flapping for straight flight
# Left servos should mirror right servos
s.add(servo_FL + servo_RL == servo_FR + servo_RR)

# Minimum flapping amplitude
s.add(servo_FL - servo_RL >= 200)  # At least 200μs difference
s.add(servo_FR - servo_RR >= 200)

if s.check() == sat:
    m = s.model()
    print(f"Valid servo commands:")
    print(f"  FL: {m[servo_FL]}")
    print(f"  FR: {m[servo_FR]}")
    print(f"  RL: {m[servo_RL]}")
    print(f"  RR: {m[servo_RR]}")
else:
    print("No valid solution exists!")
```

#### 2.2.2 Attitude Stability Verification

```python
from z3 import *

# Define real-valued variables for attitude
roll = Real('roll')
pitch = Real('pitch')
yaw = Real('yaw')

# Angular rates
roll_rate = Real('roll_rate')
pitch_rate = Real('pitch_rate')
yaw_rate = Real('yaw_rate')

# Time step
dt = 0.01  # 10ms

# Define next state
roll_next = Real('roll_next')
pitch_next = Real('pitch_next')

s = Solver()

# Current state constraints (safe region)
MAX_ROLL = 45.0
MAX_PITCH = 30.0
s.add(roll >= -MAX_ROLL, roll <= MAX_ROLL)
s.add(pitch >= -MAX_PITCH, pitch <= MAX_PITCH)

# Dynamics: θ_next = θ + ω * dt
s.add(roll_next == roll + roll_rate * dt)
s.add(pitch_next == pitch + pitch_rate * dt)

# Check if we can violate safety in one step
s.add(Or(roll_next < -MAX_ROLL, roll_next > MAX_ROLL,
         pitch_next < -MAX_PITCH, pitch_next > MAX_PITCH))

if s.check() == sat:
    m = s.model()
    print("Safety violation possible!")
    print(f"Initial: roll={m[roll]}, pitch={m[pitch]}")
    print(f"Rates: roll_rate={m[roll_rate]}, pitch_rate={m[pitch_rate]}")
    print(f"Next: roll={m[roll_next]}, pitch={m[pitch_next]}")
    
    # This indicates we need rate limiting!
else:
    print("No safety violation in one time step (proof of safety)")
```

#### 2.2.3 Battery Discharge Model Verification

```python
from z3 import *

# Battery state of charge (SOC)
SOC = Real('SOC')
SOC_next = Real('SOC_next')

# Current draw (amperes)
current = Real('current')

# Time step
dt = 0.01  # seconds

# Battery capacity
CAPACITY_AH = 0.15  # 150 mAh = 0.15 Ah

# Discharge model
CAPACITY_AS = CAPACITY_AH * 3600  # Convert to ampere-seconds

s = Solver()

# Initial conditions
s.add(SOC >= 0, SOC <= 100)
s.add(current >= 0, current <= 10)  # Max 10A continuous

# Discharge equation: SOC_next = SOC - (current * dt / CAPACITY_AS) * 100
s.add(SOC_next == SOC - (current * dt / CAPACITY_AS) * 100)

# Constraint: Never discharge below 0%
s.add(SOC_next < 0)

if s.check() == sat:
    m = s.model()
    print("Battery can be over-discharged!")
    print(f"Initial SOC: {m[SOC]}")
    print(f"Current: {m[current]} A")
    print(f"Next SOC: {m[SOC_next]}")
    print("MITIGATION: Add check: if (SOC - delta < 0) trigger_failsafe()")
else:
    print("Battery cannot be over-discharged (safe)")
```

### 2.3 Formal Verification of Control Algorithms

#### 2.3.1 PID Controller Stability

```python
from z3 import *

# PID gains
Kp = Real('Kp')
Ki = Real('Ki')
Kd = Real('Kd')

# Error terms
error = Real('error')
error_integral = Real('error_integral')
error_derivative = Real('error_derivative')

# Control output
output = Real('output')

s = Solver()

# PID equation
s.add(output == Kp * error + Ki * error_integral + Kd * error_derivative)

# Constraints on gains (stability conditions for typical 2nd-order system)
s.add(Kp > 0, Kp < 10)
s.add(Ki > 0, Ki < 1)
s.add(Kd > 0, Kd < 5)

# Error bounds
s.add(error >= -90, error <= 90)  # ±90° max error
s.add(error_integral >= -100, error_integral <= 100)
s.add(error_derivative >= -500, error_derivative <= 500)

# Output saturation check
MAX_OUTPUT = 500  # Max servo deviation from center
s.add(Or(output < -MAX_OUTPUT, output > MAX_OUTPUT))

if s.check() == sat:
    m = s.model()
    print("Control saturation possible with:")
    print(f"  Kp={m[Kp]}, Ki={m[Ki]}, Kd={m[Kd]}")
    print(f"  error={m[error]}, integral={m[error_integral]}, derivative={m[error_derivative]}")
    print(f"  output={m[output]}")
    print("MITIGATION: Add output clamping")
else:
    print("Control output always within limits")
```

#### 2.3.2 Complementary Filter Verification

```python
from z3 import *

# Complementary filter coefficient
alpha = Real('alpha')

# Accelerometer angle (noisy, low-frequency accurate)
theta_accel = Real('theta_accel')

# Gyro-integrated angle (high-frequency accurate, drifts)
theta_gyro = Real('theta_gyro')

# Filtered output
theta_filtered = Real('theta_filtered')

# Previous filtered angle
theta_prev = Real('theta_prev')

# Gyro rate
omega = Real('omega')
dt = 0.01

s = Solver()

# Complementary filter equation
# theta_filtered = alpha * (theta_prev + omega*dt) + (1-alpha) * theta_accel
s.add(theta_filtered == alpha * (theta_prev + omega * dt) + (1 - alpha) * theta_accel)

# Alpha must be in (0, 1) for stability
s.add(alpha > 0, alpha < 1)

# Typical alpha around 0.98
s.add(alpha >= 0.95, alpha <= 0.99)

# Check: Can filtered angle exceed physical limits given bounded inputs?
s.add(theta_accel >= -90, theta_accel <= 90)
s.add(theta_prev >= -90, theta_prev <= 90)
s.add(omega >= -500, omega <= 500)  # deg/s

# Safety violation
s.add(Or(theta_filtered < -100, theta_filtered > 100))

if s.check() == sat:
    m = s.model()
    print("Filter can produce out-of-range angles!")
    print(f"  alpha={m[alpha]}")
    print(f"  theta_accel={m[theta_accel]}, theta_gyro={m[theta_gyro]}")
    print(f"  omega={m[omega]}, theta_prev={m[theta_prev]}")
    print(f"  theta_filtered={m[theta_filtered]}")
else:
    print("Filter output always within bounds (verified)")
```

### 2.4 Multi-Constraint Optimization

#### 2.4.1 Optimal Flapping Parameters

```python
from z3 import *

# Flapping parameters
freq = Real('freq')           # Hz
amplitude = Real('amplitude') # degrees
phase_delay = Real('phase_delay') # degrees

# Performance metrics
thrust = Real('thrust')       # Newtons
power = Real('power')         # Watts
efficiency = Real('efficiency') # thrust/power

s = Optimize()  # Use Optimize instead of Solver for optimization

# Physical constraints
s.add(freq >= 3, freq <= 7)
s.add(amplitude >= 30, amplitude <= 60)
s.add(phase_delay >= 0, phase_delay <= 90)

# Simplified aerodynamic models
# Thrust proportional to freq^2 * amplitude
s.add(thrust == 0.01 * freq * freq * amplitude)

# Power proportional to freq^3 * amplitude^2
s.add(power == 0.001 * freq * freq * freq * amplitude * amplitude)

# Efficiency
s.add(efficiency == thrust / power)

# Minimum thrust requirement (must overcome weight)
WEIGHT = 0.5  # Newtons (50g ornithopter)
s.add(thrust >= WEIGHT * 1.5)  # 1.5x safety margin

# Maximize efficiency
s.maximize(efficiency)

if s.check() == sat:
    m = s.model()
    print("Optimal flapping parameters:")
    print(f"  Frequency: {m[freq]} Hz")
    print(f"  Amplitude: {m[amplitude]}°")
    print(f"  Phase delay: {m[phase_delay]}°")
    print(f"  Thrust: {m[thrust]} N")
    print(f"  Power: {m[power]} W")
    print(f"  Efficiency: {m[efficiency]} N/W")
else:
    print("No feasible solution")
```

## 3. Integration with Control System

### 3.1 Pre-Flight Verification

```cpp
// Arduino code snippet for runtime verification

bool verifyControlLaw(int servo_FL, int servo_FR, int servo_RL, int servo_RR) {
    // Check servo range constraints
    if (servo_FL < MIN_SERVO || servo_FL > MAX_SERVO) return false;
    if (servo_FR < MIN_SERVO || servo_FR > MAX_SERVO) return false;
    if (servo_RL < MIN_SERVO || servo_RL > MAX_SERVO) return false;
    if (servo_RR < MIN_SERVO || servo_RR > MAX_SERVO) return false;
    
    // Check minimum flapping amplitude
    if (abs(servo_FL - servo_RL) < MIN_FLAP_AMP) return false;
    if (abs(servo_FR - servo_RR) < MIN_FLAP_AMP) return false;
    
    // Check symmetric constraints for straight flight
    int left_sum = servo_FL + servo_RL;
    int right_sum = servo_FR + servo_RR;
    if (abs(left_sum - right_sum) > SYMMETRY_TOLERANCE) {
        // Asymmetric - check if intentional turn
        if (flightMode != TURN) return false;
    }
    
    return true;  // All constraints satisfied
}
```

### 3.2 Runtime Monitoring

```cpp
class RuntimeMonitor {
private:
    float roll, pitch, yaw;
    float roll_rate, pitch_rate, yaw_rate;
    
public:
    bool checkAttitudeSafety() {
        if (abs(roll) > MAX_ROLL || abs(pitch) > MAX_PITCH) {
            triggerFailsafe("ATTITUDE_LIMIT");
            return false;
        }
        return true;
    }
    
    bool checkRateLimits() {
        if (abs(roll_rate) > MAX_ROLL_RATE || 
            abs(pitch_rate) > MAX_PITCH_RATE ||
            abs(yaw_rate) > MAX_YAW_RATE) {
            triggerFailsafe("RATE_LIMIT");
            return false;
        }
        return true;
    }
    
    bool checkInvariants() {
        return checkAttitudeSafety() && checkRateLimits();
    }
};
```

## 4. Verification Workflow

### 4.1 Development Process

```
1. Specify system in TLA+
   ├─ Define states and actions
   ├─ Write safety properties
   └─ Write liveness properties

2. Model check with TLC
   ├─ Find violations
   ├─ Refine specification
   └─ Iterate until verified

3. Generate constraints for Z3
   ├─ Extract critical properties
   ├─ Formalize as SMT constraints
   └─ Verify mathematically

4. Synthesize runtime monitors
   ├─ Convert invariants to C++ code
   ├─ Integrate with control loop
   └─ Test on hardware

5. Continuous verification
   ├─ Log runtime violations
   ├─ Update formal model
   └─ Re-verify
```

### 4.2 Automated Test Generation

```python
# Generate test cases from Z3 models

def generate_test_cases():
    test_cases = []
    
    # Boundary conditions
    servos = [Int(f'servo_{i}') for i in range(4)]
    s = Solver()
    
    for servo in servos:
        s.push()
        s.add(servo == MIN_SERVO)
        if s.check() == sat:
            test_cases.append(s.model())
        s.pop()
        
        s.push()
        s.add(servo == MAX_SERVO)
        if s.check() == sat:
            test_cases.append(s.model())
        s.pop()
    
    return test_cases

# Generate test vectors
tests = generate_test_cases()
for i, test in enumerate(tests):
    print(f"Test {i}: {test}")
```

## 5. Technical Debt and Recommendations

### 5.1 Current Gaps

1. **No formal specification**: System behavior not rigorously defined
2. **Lack of verification**: Safety properties not proven
3. **No runtime monitoring**: Violations detected reactively, not proactively
4. **Missing test coverage**: Corner cases not systematically explored

### 5.2 Implementation Roadmap

**Phase 1: Specification** (1-2 weeks)
- Write TLA+ specification for current system
- Define safety and liveness properties
- Model check with TLC

**Phase 2: Verification** (2-3 weeks)
- Formalize critical constraints in Z3
- Verify control algorithms
- Generate proofs of safety

**Phase 3: Monitoring** (1-2 weeks)
- Synthesize runtime monitors from specifications
- Integrate with Arduino code
- Test on hardware

**Phase 4: Continuous Integration** (ongoing)
- Automate verification in CI/CD pipeline
- Maintain specification alongside code
- Update based on flight data

## 6. References

1. Lamport, L. (2002). "Specifying Systems: The TLA+ Language and Tools"
2. de Moura, L. & Bjørner, N. (2008). "Z3: An Efficient SMT Solver"
3. Clarke, E. et al. (2018). "Handbook of Model Checking"
4. Leucker, M. & Schallhart, C. (2009). "A brief account of runtime verification"

## 7. Conclusion

Formal methods provide:
- **Mathematical rigor**: Precise specification of system behavior
- **Verification**: Proofs of safety and correctness
- **Automatic test generation**: Systematic coverage of corner cases
- **Runtime monitoring**: Early detection of violations
- **Confidence**: Formal guarantees for safety-critical operations

Integration of TLA+ and Z3 into the development workflow will significantly improve the reliability and safety of the ornithopter control system.

## Appendix A: Running TLA+ Model Checker

```bash
# Install TLA+ Toolbox
# Download from: https://github.com/tlaplus/tlaplus/releases

# Run model checker
java -jar tla2tools.jar -config OrnithopterFlightControl.cfg OrnithopterFlightControl.tla

# Or use TLC command line:
tlc2 OrnithopterFlightControl.tla -config OrnithopterFlightControl.cfg
```

## Appendix B: Z3 Python API Examples

```bash
# Install Z3
pip install z3-solver

# Run verification script
python ornithopter_verification.py
```
