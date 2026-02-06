# Carpooling Platform - Test Suite

This directory contains a professional pytest-based test suite for the carpooling platform backend.

## Overview

The test suite provides comprehensive coverage of all API endpoints, including:

- **Authentication** (`test_auth.py`) - User registration, login, JWT handling
- **Rides** (`test_rides.py`) - Ride creation, listing, updates, completion
- **Reservations** (`test_reservations.py`) - Booking, approval, rejection, cancellation
- **Notifications** (`test_notifications.py`) - Notification creation and management
- **Edge Cases** (`test_edge_cases.py`) - Security, boundaries, error handling
- **Integration** (`integration_test.py`) - Legacy end-to-end flow tests

## Quick Start

### Prerequisites

```bash
# Install pytest and dependencies
pip install pytest pytest-cov requests

# Optional: For load testing
pip install locust
```

### Run All Tests

```bash
# Run all tests
pytest

# Run with coverage report
pytest --cov=app --cov-report=term-missing

# Run with verbose output
pytest -v

# Run specific test file
pytest tests/test_auth.py -v

# Run specific test class
pytest tests/test_auth.py::TestAuthRegistration -v

# Run specific test
pytest tests/test_auth.py::TestAuthRegistration::test_register_success -v
```

## Test Structure

### Fixtures (`conftest.py`)

The `conftest.py` file provides reusable fixtures:

- `app` - Flask application with in-memory test database
- `client` - Test HTTP client
- `test_driver` - Pre-registered driver employee
- `test_passenger` - Pre-registered passenger employee
- `driver_token` / `passenger_token` - JWT tokens
- `auth_headers_driver` / `auth_headers_passenger` - Auth headers
- `sample_ride` - Pre-created ride
- `sample_reservation` / `confirmed_reservation` - Pre-created reservations

### Configuration (`config.py`)

Test-specific configuration:

- Uses in-memory SQLite for fast tests
- Separate JWT secret key
- Faster password hashing (BCRYPT_LOG_ROUNDS=4)
- Disabled CSRF for testing

### Writing New Tests

Example test structure:

```python
def test_create_ride_success(self, client, auth_headers_driver, test_driver):
    """Test creating a new ride."""
    response = client.post('/rides/', headers=auth_headers_driver, json={
        'driver_id': test_driver.id,
        'origin': 'Downtown',
        'destination': 'Airport',
        'departure_time': '2026-02-10T10:00:00',
        'available_seats': 3
    })
    
    assert response.status_code == 201
    assert response.json['origin'] == 'Downtown'
```

## Test Categories

### Unit Tests

Test individual endpoints in isolation using fixtures.

### Integration Tests

Test complete user flows across multiple endpoints.

### Security Tests

- SQL injection attempts
- XSS prevention
- Access control (403 Forbidden)
- Authentication (401 Unauthorized)
- Expired tokens

### Edge Case Tests

- Boundary conditions
- Invalid inputs
- Race conditions
- Data consistency

## Load Testing

### Using Locust

Start the Flask server:
```bash
flask run
```

Run load tests:
```bash
locust -f tests/load_test.py --host=http://127.0.0.1:5000
```

Open browser at http://localhost:8089 and set:
- Number of users: 10-100
- Spawn rate: 1-5 users/second

Locust simulates:
- **DriverUser**: Creates rides, views participants
- **PassengerUser**: Searches rides, makes reservations
- **AdminUser**: Views statistics

## CI/CD Integration

Add to your CI pipeline (GitHub Actions example):

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - run: pip install pytest pytest-cov
      - run: pytest --cov=app --cov-report=xml
      - uses: codecov/codecov-action@v3
```

## Test Isolation

Each test:
- Runs with fresh in-memory database
- Uses isolated fixtures
- Cleans up after completion
- Never affects production data

## Troubleshooting

### Tests failing with 401 Unauthorized

Check that fixtures are being used correctly:
```python
def test_example(self, client, auth_headers_driver):
    response = client.get('/rides/', headers=auth_headers_driver)
```

### Database locked errors

SQLite doesn't support concurrent writes well. Tests should be fast enough to avoid this.

### Import errors

Ensure the parent directory is in the Python path (handled in `conftest.py`).

## Coverage Goals

- **Minimum**: 80% code coverage
- **Target**: 90% code coverage
- **Focus areas**: Authentication, reservations, error handling

## Best Practices

1. **Use fixtures** - Don't recreate test data manually
2. **Assert on status codes** - Verify both success and error cases
3. **Test error responses** - Check `error` and `message` fields
4. **Keep tests isolated** - Don't depend on test order
5. **Use descriptive names** - `test_create_ride_invalid_seats`
6. **Add docstrings** - Explain what the test validates
