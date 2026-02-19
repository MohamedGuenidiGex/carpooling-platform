"""Admin Analytics Service - SQLAlchemy aggregation queries for dashboard metrics."""

from datetime import datetime, timedelta
from sqlalchemy import func, and_, cast, Date
from app import db
from app.models.employee import Employee
from app.models.ride import Ride
from app.models.reservation import Reservation


class AdminAnalyticsService:
    """Service for computing admin dashboard analytics."""

    @staticmethod
    def get_dashboard_summary():
        """Get dashboard summary metrics.

        Returns:
            dict: Contains users_total, users_today, active_rides,
                  rides_total, reservations_total, system_status
        """
        try:
            today = datetime.utcnow().date()
            today_start = datetime.combine(today, datetime.min.time())
            today_end = datetime.combine(today, datetime.max.time())

            # Users total
            users_total = db.session.query(func.count(Employee.id)).scalar() or 0

            # Users created today
            users_today = (
                db.session.query(func.count(Employee.id))
                .filter(
                    Employee.created_at >= today_start,
                    Employee.created_at <= today_end
                )
                .scalar() or 0
            )

            # Active rides (status in ACTIVE or FULL)
            active_rides = (
                db.session.query(func.count(Ride.id))
                .filter(Ride.status.in_(['ACTIVE', 'FULL']))
                .scalar() or 0
            )

            # Total rides
            rides_total = db.session.query(func.count(Ride.id)).scalar() or 0

            # Total reservations
            reservations_total = (
                db.session.query(func.count(Reservation.id))
                .filter(Reservation.status != 'CANCELLED')
                .scalar() or 0
            )

            return {
                'users_total': users_total,
                'users_today': users_today,
                'active_rides': active_rides,
                'rides_total': rides_total,
                'reservations_total': reservations_total,
                'system_status': 'operational'
            }
        except Exception as e:
            import logging
            logging.error(f'Error in get_dashboard_summary: {e}')
            return {
                'users_total': 0,
                'users_today': 0,
                'active_rides': 0,
                'rides_total': 0,
                'reservations_total': 0,
                'system_status': 'error'
            }

    @staticmethod
    def get_trends(days=7):
        """Get system trends for the last N days.

        Args:
            days: Number of days to look back (default 7, max 365)

        Returns:
            dict: Contains rides_per_day and reservations_per_day arrays
        """
        try:
            days = max(1, min(365, days))
            end_date = datetime.utcnow().date()
            start_date = end_date - timedelta(days=days - 1)

            # Generate all dates in range
            date_range = []
            current = start_date
            while current <= end_date:
                date_range.append(current)
                current += timedelta(days=1)

            # Rides per day - use cast to Date for better cross-database compatibility
            rides_query = (
                db.session.query(
                    cast(Ride.created_at, Date).label('date'),
                    func.count(Ride.id).label('count')
                )
                .filter(
                    cast(Ride.created_at, Date) >= start_date,
                    cast(Ride.created_at, Date) <= end_date
                )
                .group_by(cast(Ride.created_at, Date))
                .all()
            )

            rides_map = {str(row.date): row.count for row in rides_query}
            rides_per_day = [
                {'date': d.isoformat(), 'count': rides_map.get(d.isoformat(), 0)}
                for d in date_range
            ]

            # Reservations per day
            reservations_query = (
                db.session.query(
                    cast(Reservation.created_at, Date).label('date'),
                    func.count(Reservation.id).label('count')
                )
                .filter(
                    cast(Reservation.created_at, Date) >= start_date,
                    cast(Reservation.created_at, Date) <= end_date,
                    Reservation.status != 'CANCELLED'
                )
                .group_by(cast(Reservation.created_at, Date))
                .all()
            )

            reservations_map = {str(row.date): row.count for row in reservations_query}
            reservations_per_day = [
                {'date': d.isoformat(), 'count': reservations_map.get(d.isoformat(), 0)}
                for d in date_range
            ]

            return {
                'rides_per_day': rides_per_day,
                'reservations_per_day': reservations_per_day
            }
        except Exception as e:
            import logging
            logging.error(f'Error in get_trends: {e}')
            return {
                'rides_per_day': [],
                'reservations_per_day': []
            }

    @staticmethod
    def get_top_routes(limit=5):
        """Get top routes by reservation count.

        Args:
            limit: Number of routes to return (default 5)

        Returns:
            dict: Contains routes array with origin, destination,
                  rides count, and reservations count
        """
        try:
            # Query rides grouped by origin-destination
            routes_data = (
                db.session.query(
                    Ride.origin,
                    Ride.destination,
                    func.count(Ride.id).label('ride_count')
                )
                .group_by(Ride.origin, Ride.destination)
                .order_by(func.count(Ride.id).desc())
                .limit(limit)
                .all()
            )

            routes = []
            for row in routes_data:
                # Count reservations for this route
                res_count = (
                    db.session.query(func.count(Reservation.id))
                    .join(Ride, Reservation.ride_id == Ride.id)
                    .filter(
                        Ride.origin == row.origin,
                        Ride.destination == row.destination,
                        Reservation.status != 'CANCELLED'
                    )
                    .scalar() or 0
                )

                routes.append({
                    'origin': row.origin,
                    'destination': row.destination,
                    'rides': row.ride_count,
                    'reservations': res_count
                })

            # Sort by reservations descending
            routes.sort(key=lambda x: x['reservations'], reverse=True)

            return {'routes': routes[:limit]}
        except Exception as e:
            import logging
            logging.error(f'Error in get_top_routes: {e}')
            return {'routes': []}

    @staticmethod
    def get_ride_status_distribution():
        """Get distribution of ride statuses for donut chart.

        Returns:
            dict: Contains counts per status key.
        """
        try:
            rows = (
                db.session.query(Ride.status, func.count(Ride.id))
                .group_by(Ride.status)
                .all()
            )

            counts = {str(status): int(count) for status, count in rows}

            # Normalize to expected keys
            return {
                'active': counts.get('ACTIVE', 0) + counts.get('FULL', 0),
                'completed': counts.get('COMPLETED', 0),
                'cancelled': counts.get('CANCELLED', 0),
            }
        except Exception as e:
            import logging
            logging.error(f'Error in get_ride_status_distribution: {e}')
            return {'active': 0, 'completed': 0, 'cancelled': 0}

    @staticmethod
    def get_recent_activity(limit=10):
        """Get recent reservation activity for the activity table.

        Returns:
            dict: Contains activity list.
        """
        try:
            limit = max(1, min(100, int(limit)))

            rows = (
                db.session.query(
                    Reservation.created_at.label('created_at'),
                    Reservation.status.label('status'),
                    Employee.name.label('name'),
                    Ride.origin.label('origin'),
                    Ride.destination.label('destination'),
                )
                .join(Employee, Reservation.employee_id == Employee.id)
                .join(Ride, Reservation.ride_id == Ride.id)
                .order_by(Reservation.created_at.desc())
                .limit(limit)
                .all()
            )

            items = []
            for r in rows:
                user = (r.name or '').strip() or 'Unknown'

                items.append({
                    'user': user,
                    'route': f"{r.origin} → {r.destination}",
                    'time': r.created_at.isoformat() if r.created_at else None,
                    'status': r.status,
                })

            return {'items': items}
        except Exception as e:
            import logging
            logging.error(f'Error in get_recent_activity: {e}')
            return {'items': []}
