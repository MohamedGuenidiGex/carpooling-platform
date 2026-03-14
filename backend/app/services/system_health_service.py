"""System Health Service - Monitors the health of core platform services."""

import requests
from datetime import datetime, timedelta
from sqlalchemy import text
from app.extensions import db
from app.models import Ride, Reservation, Employee

# OSRM configuration
OSRM_BASE_URL = "http://router.project-osrm.org"
OSRM_TIMEOUT = 5  # seconds - quick timeout to avoid blocking

# GPS stream tracking - stores last driver location update timestamp
gps_last_update_cache = {}


def check_api_health():
    """Check if the API server is responding.
    
    Returns:
        dict: {"status": "online"}
    """
    return {"status": "online"}


def check_database_health():
    """Check if the database is healthy by performing a lightweight query.
    
    Returns:
        dict: {"status": "healthy"} or {"status": "down"}
    """
    try:
        # Perform lightweight query
        db.session.execute(text("SELECT 1"))
        return {"status": "healthy"}
    except Exception as e:
        return {"status": "down"}


def check_websocket_health():
    """Check WebSocket service status.
    
    Returns:
        dict: {"status": "connected", "active_connections": int} or {"status": "idle"}
    """
    try:
        # Try to import and check socketio instance
        from app.extensions import socketio
        
        # If socketio exists, consider it operational
        # Note: Actual connection metrics would require more complex tracking
        if socketio:
            return {"status": "connected", "active_connections": 0}
        else:
            return {"status": "idle"}
    except Exception as e:
        return {"status": "idle"}


def check_osrm_health():
    """Check OSRM routing server health with a small test request.
    
    Returns:
        dict: {"status": "responding"} or {"status": "down"}
    """
    try:
        # Test coordinates: 10.18,36.80 → 10.19,36.81 (Tunisia area)
        test_url = f"{OSRM_BASE_URL}/route/v1/driving/10.18,36.80;10.19,36.81"
        
        response = requests.get(
            test_url,
            timeout=OSRM_TIMEOUT,
            params={"overview": "false"}
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get("code") == "Ok":
                return {"status": "responding"}
        
        return {"status": "down"}
    except requests.Timeout:
        return {"status": "down"}
    except requests.RequestException:
        return {"status": "down"}
    except Exception:
        return {"status": "down"}


def check_gps_stream_health():
    """Check if GPS stream has recent driver location updates.
    
    Returns four states:
    - "idle": No active drivers (system healthy but nothing to track)
    - "active": Last update < 60 seconds ago
    - "degraded": Last update 60-180 seconds ago
    - "inactive": Last update > 180 seconds ago or no recent data
    
    Returns:
        dict: {"status": "idle" | "active" | "degraded" | "inactive"}
    """
    try:
        # Step 1: Check if there are any active drivers (via active rides)
        active_rides = Ride.query.filter(
            Ride.status.in_(['in_progress', 'active'])
        ).count()
        
        # Also check for pending rides as drivers may be streaming GPS
        # while waiting for passengers
        pending_rides = Ride.query.filter(
            Ride.status.in_(['pending', 'scheduled'])
        ).count()
        
        total_active_drivers = active_rides + pending_rides
        
        # If no active drivers, GPS stream is idle (not failing)
        if total_active_drivers == 0:
            return {"status": "idle"}
        
        # Step 2: Check timestamp of latest driver location update
        # Use Employee.last_seen_at as the indicator for recent GPS activity
        now = datetime.utcnow()
        
        try:
            # Find the most recent driver location update
            latest_driver = Employee.query.filter(
                Employee.last_seen_at.isnot(None)
            ).order_by(Employee.last_seen_at.desc()).first()
            
            if latest_driver and latest_driver.last_seen_at:
                seconds_since_update = (now - latest_driver.last_seen_at).total_seconds()
                
                if seconds_since_update < 60:
                    return {"status": "active"}
                elif seconds_since_update < 180:
                    return {"status": "degraded"}
                else:
                    return {"status": "inactive"}
            else:
                # No location data available but drivers are active
                # This is degraded - we should have data but don't
                return {"status": "degraded"}
                
        except Exception:
            # If we can't check timestamps but drivers are active, assume degraded
            return {"status": "degraded"}
            
    except Exception:
        # On complete failure, return inactive
        return {"status": "inactive"}


def get_system_health():
    """Run all health checks and return aggregated status.
    
    Returns:
        dict: Complete health status of all system components
    """
    checked_at = datetime.utcnow().isoformat()
    
    # Run all health checks with error handling
    health_results = {
        "checked_at": checked_at
    }
    
    # API Health
    try:
        api_result = check_api_health()
        health_results["api"] = api_result.get("status", "down")
    except Exception:
        health_results["api"] = "down"
    
    # Database Health
    try:
        db_result = check_database_health()
        health_results["database"] = db_result.get("status", "down")
    except Exception:
        health_results["database"] = "down"
    
    # WebSocket Health
    try:
        ws_result = check_websocket_health()
        health_results["websocket"] = ws_result.get("status", "down")
    except Exception:
        health_results["websocket"] = "down"
    
    # OSRM Health
    try:
        osrm_result = check_osrm_health()
        health_results["osrm"] = osrm_result.get("status", "down")
    except Exception:
        health_results["osrm"] = "down"
    
    # GPS Stream Health
    try:
        gps_result = check_gps_stream_health()
        health_results["gps_stream"] = gps_result.get("status", "down")
    except Exception:
        health_results["gps_stream"] = "down"
    
    return health_results
