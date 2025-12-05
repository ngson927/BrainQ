
import logging
from django.utils.deprecation import MiddlewareMixin
from .models import SecurityLog

logger = logging.getLogger("security")

class SecurityAuditMiddleware(MiddlewareMixin):
    def process_response(self, request, response):
        try:
            status = getattr(response, "status_code", None)
            if status in (401, 403):
                user = getattr(request, "user", None)
                user_id = user.id if getattr(user, "is_authenticated", False) else None
                ip = request.META.get("REMOTE_ADDR") or request.META.get("HTTP_X_FORWARDED_FOR")

                # Safely read body
                try:
                    body_content = None
                    if hasattr(request, "_body"):
                        body_content = request._body.decode("utf-8")[:1000]
                except Exception:
                    body_content = None

                details = {
                    "path": request.path,
                    "method": request.method,
                    "query_params": request.GET.dict(),
                    "body": body_content,
                }

                try:
                    SecurityLog.objects.create(
                        user_id=user_id,
                        action="unauthorized_access",
                        ip_address=ip,
                        details=details
                    )
                except Exception as exc:
                    logger.exception("Failed to write SecurityLog: %s", exc)

                # Use plain text logging to avoid Unicode errors on Windows
                logger.warning(
                    "Unauthorized access: user=%s path=%s status=%s ip=%s",
                    user_id, request.path, status, ip
                )
        except Exception:
            logger.exception("Error in SecurityAuditMiddleware")
        return response

