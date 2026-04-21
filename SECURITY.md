# Security Policy

## Custom Action Validation Rules (Android)

To prevent resource injection and potential system instability, the following validation rules are enforced for custom media session actions on Android:

### 1. Resource ID Validation
- **Icon Resource Name**: Must match the regex `^[a-z0-9_]+$`.
- **Lookup**: Resources are only looked up within the application's own package (`drawable` type).

### 2. Bundle Serialization
- **Extras Size**: A maximum of 50 entries are allowed per custom action `extras` bundle.
- **Key Format**: Keys must match the regex `^[a-zA-Z0-9_]+$`.
- **String Length**: String values within extras are limited to 1000 characters.
- **Supported Types**: String, Int, Boolean, Double, Float.

### 3. Input Sanitization
- **Action Name**: Must not be null or blank.
- **Display Label**: Must not be null or blank.
- **Icon Resource**: Must not be null or blank.

## Memory Management
- **Controller Commands**: The mapping of connected controllers to their available commands is capped at 100 entries using an LRU (Least Recently Used) strategy to prevent memory exhaustion in scenarios with rapid connection/disconnection cycles.
