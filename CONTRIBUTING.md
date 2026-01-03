# Contributing to 4-Servo Ornithopter Control System

Thank you for your interest in contributing to this research-grade ornithopter control system! This document provides guidelines and best practices for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Submitting Changes](#submitting-changes)

## Code of Conduct

This project adheres to a code of conduct that emphasizes:
- **Respect**: Treat all contributors with respect
- **Collaboration**: Work together constructively
- **Quality**: Maintain high standards for code and documentation
- **Safety**: Prioritize safety in all flight control software

## Getting Started

### Prerequisites

1. **Install Development Tools**:
   ```bash
   # PlatformIO
   pip install platformio
   
   # Git
   sudo apt-get install git
   
   # Python 3.7+
   python3 --version
   ```

2. **Fork and Clone**:
   ```bash
   # Fork the repository on GitHub
   # Then clone your fork
   git clone https://github.com/YOUR_USERNAME/4ServoFlapOrnithopter.git
   cd 4ServoFlapOrnithopter
   
   # Add upstream remote
   git remote add upstream https://github.com/Oichkatzelesfrettschen/4ServoFlapOrnithopter.git
   ```

3. **Build and Test**:
   ```bash
   # Build firmware
   pio run -e pro_mini_5v
   
   # Run tests
   pio test -e native
   ```

### Project Structure

```
4ServoFlapOrnithopter/
├── docs/                   # Comprehensive documentation
├── sketch_*/              # Arduino sketches (original code)
├── src/                   # Source code (future refactoring)
├── lib/                   # Project libraries
├── test/                  # Unit tests
├── scripts/               # Build automation scripts
├── .github/workflows/     # CI/CD configuration
├── platformio.ini         # Build configuration
└── README.md
```

## Development Workflow

### 1. Create a Branch

```bash
# Update your fork
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/your-feature-name
```

### 2. Make Changes

Follow these principles:
- **Minimal changes**: Make the smallest change that achieves the goal
- **One feature per branch**: Don't mix unrelated changes
- **Incremental commits**: Commit logical units of work
- **Clear messages**: Write descriptive commit messages

### 3. Test Your Changes

```bash
# Run unit tests
pio test -e native

# Build for target platforms
pio run -e pro_mini_5v
pio run -e with_imu

# Static analysis
pio check -e pro_mini_5v

# Format code
clang-format -i src/**/*.cpp src/**/*.h
```

### 4. Update Documentation

- Update relevant markdown files in `docs/`
- Add code comments for complex logic
- Update README if adding new features
- Generate Doxygen docs: `doxygen Doxyfile`

## Coding Standards

### C/C++ Style

Follow these conventions:

```cpp
// Use meaningful names
float computeLiftForce(float velocity, float angle);

// Constants in UPPER_CASE
const int MAX_SERVO_POSITION = 2000;

// Classes in PascalCase
class QuaternionFilter {
public:
    void update(float dt);
    
private:
    float orientation[4];
};

// Functions and variables in camelCase
void updateServoPositions() {
    int servoCommand = calculateCommand();
}

// Use const correctness
const float* getOrientation() const;

// Prefer early returns
bool isValid(float value) {
    if (value < MIN_VALUE) return false;
    if (value > MAX_VALUE) return false;
    return true;
}

// Document complex algorithms
/**
 * @brief Computes quaternion from angular velocity using RK4 integration
 * @param omega Angular velocity vector [rad/s]
 * @param dt Time step [s]
 * @return Updated quaternion
 */
Quaternion integrateQuaternion(const float omega[3], float dt);
```

### Formatting

Use clang-format with provided `.clang-format`:
```bash
# Format all source files
find src -name "*.cpp" -o -name "*.h" | xargs clang-format -i
```

### Memory Safety

On Arduino with limited RAM:
- Avoid dynamic allocation (`new`, `malloc`)
- Use stack allocation and `static` storage
- Check buffer bounds
- Use `constexpr` for compile-time constants
- Store large constants in `PROGMEM`

### Error Handling

```cpp
// Check return values
if (!sensor.begin()) {
    Serial.println("ERROR: Sensor init failed");
    return false;
}

// Validate inputs
bool setServoPosition(int position) {
    if (position < MIN_SERVO || position > MAX_SERVO) {
        return false;  // Invalid input
    }
    servo.write(position);
    return true;
}

// Use assertions for development
#ifdef DEBUG
    assert(orientation.magnitude() > 0.999f);
#endif
```

## Testing Requirements

### Unit Tests

All new functionality must include unit tests:

```cpp
// test/test_quaternion.cpp
#include <unity.h>
#include "quaternion.h"

void test_quaternion_normalize() {
    Quaternion q = {1.0f, 2.0f, 3.0f, 4.0f};
    q.normalize();
    
    float mag = q.magnitude();
    TEST_ASSERT_FLOAT_WITHIN(0.001f, 1.0f, mag);
}

void setUp(void) { /* runs before each test */ }
void tearDown(void) { /* runs after each test */ }

void setup() {
    UNITY_BEGIN();
    RUN_TEST(test_quaternion_normalize);
    UNITY_END();
}

void loop() {}
```

### Hardware-in-the-Loop (HIL)

For hardware-dependent code:
1. Create mock interfaces
2. Test with mock in `native` environment
3. Validate on actual hardware
4. Document test procedure

### Test Coverage

Aim for:
- **Unit tests**: >80% code coverage
- **Integration tests**: All major features
- **Hardware tests**: Critical flight control paths

## Documentation

### Code Documentation

Use Doxygen-style comments:

```cpp
/**
 * @brief Updates the orientation estimate using sensor fusion
 * 
 * Implements Madgwick gradient descent algorithm combining
 * gyroscope, accelerometer, and magnetometer data.
 * 
 * @param[in] gyro Angular velocity [rad/s] (3D vector)
 * @param[in] accel Acceleration [m/s²] (3D vector)
 * @param[in] mag Magnetic field [µT] (3D vector)
 * @param[in] dt Time step [s]
 * 
 * @return true if successful, false if sensor data invalid
 * 
 * @note Requires normalized accelerometer and magnetometer readings
 * @warning Do not call faster than 100 Hz to avoid instability
 */
bool updateOrientation(const float gyro[3], const float accel[3], 
                       const float mag[3], float dt);
```

### Markdown Documentation

For conceptual documentation in `docs/`:
- Use clear headings
- Include equations in LaTeX: `$F = ma$` or `$$\int f(x)dx$$`
- Add diagrams when helpful
- Link to related documents
- Provide code examples

### README Updates

When adding features:
1. Update feature list
2. Add usage examples
3. Update build instructions if needed
4. Link to detailed documentation

## Submitting Changes

### Pull Request Process

1. **Ensure Quality**:
   ```bash
   # All tests pass
   pio test -e native
   
   # Code builds for all targets
   pio run
   
   # No linting errors
   pio check
   ```

2. **Update CHANGELOG**: Document your changes

3. **Create Pull Request**:
   - Write clear title: "Add quaternion-based orientation tracking"
   - Describe what and why (not just how)
   - Reference related issues: "Fixes #123"
   - Include test results
   - Add before/after comparisons if relevant

4. **Review Process**:
   - CI must pass (automated checks)
   - At least one maintainer review
   - Address feedback constructively
   - Update based on comments

### Commit Messages

Follow conventional commits:

```
type(scope): subject

body (optional)

footer (optional)
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting changes
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Build system, dependencies

Examples:
```
feat(sensors): add MPU6050 IMU integration

Implements I2C communication with MPU6050 6-DOF IMU.
Includes Madgwick filter for sensor fusion.

Closes #42

---

fix(control): prevent servo command overflow

Clamp servo commands to [1000, 2000] µs range to prevent
hardware damage.

---

docs(math): add quaternion rotation tutorial

Comprehensive guide on quaternion mathematics for orientation
tracking, including code examples and visualizations.
```

## Areas Needing Contribution

### High Priority
- [ ] Quaternion library implementation
- [ ] MPU6050 IMU driver and Madgwick filter
- [ ] Unit tests for existing code
- [ ] Hardware-in-the-loop test framework

### Medium Priority
- [ ] MLP neural network training pipeline
- [ ] Battery SOC estimation algorithm
- [ ] Autonomous waypoint navigation
- [ ] Telemetry logging system

### Low Priority
- [ ] Ground station GUI
- [ ] Vision-based navigation
- [ ] Multi-agent coordination
- [ ] Advanced FSI modeling

### Documentation
- [ ] Flight testing procedures
- [ ] Calibration guides
- [ ] Troubleshooting guide
- [ ] Video tutorials

## Questions?

- **Issues**: [GitHub Issues](https://github.com/Oichkatzelesfrettschen/4ServoFlapOrnithopter/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Oichkatzelesfrettschen/4ServoFlapOrnithopter/discussions)
- **Email**: See maintainer contact in README

## License

By contributing, you agree that your contributions will be licensed under the GNU General Public License v3.0.

---

Thank you for contributing to advancing ornithopter flight control technology! 🦅
