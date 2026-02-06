"""Centralized structured logging utility for the carpooling platform."""
import logging
import sys
from datetime import datetime
from typing import Any, Dict, Optional


def setup_logger(name: str = "carpooling") -> logging.Logger:
    """Set up and configure the structured logger."""
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)
    
    # Create console handler
    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(logging.INFO)
    
    # Create custom formatter for structured output
    class StructuredFormatter(logging.Formatter):
        def format(self, record: logging.LogRecord) -> str:
            timestamp = datetime.fromtimestamp(record.created).strftime("%Y-%m-%d %H:%M:%S")
            action = getattr(record, 'action', 'UNKNOWN')
            employee_id = getattr(record, 'employee_id', None)
            details = getattr(record, 'details', {})
            
            # Build log line
            parts = [f"[{timestamp}]", f"Action: {action}"]
            
            if employee_id:
                parts.append(f"Employee: {employee_id}")
            
            if details:
                details_str = ", ".join([f"{k}={v}" for k, v in details.items()])
                parts.append(f"Details: {details_str}")
            
            return " | ".join(parts)
    
    handler.setFormatter(StructuredFormatter())
    
    # Remove existing handlers and add our handler
    logger.handlers = []
    logger.addHandler(handler)
    
    return logger


# Global logger instance
logger = setup_logger()


def log_action(
    action: str,
    employee_id: Optional[int] = None,
    details: Optional[Dict[str, Any]] = None
) -> None:
    """Log a structured action with timestamp, employee_id, and relevant details.
    
    Args:
        action: Name of the action being logged
        employee_id: ID of the employee performing the action
        details: Dictionary of relevant entity IDs and additional info
    """
    extra = {
        'action': action,
        'employee_id': employee_id,
        'details': details or {}
    }
    logger.info('', extra=extra)
