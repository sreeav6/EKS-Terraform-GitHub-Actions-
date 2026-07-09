from flask import Flask, request, jsonify
from datetime import datetime, timezone

app = Flask(__name__)


@app.route("/")
def time_and_ip():
    """Return the current UTC timestamp and the visitor's IP as JSON."""
    # Honour the X-Forwarded-For header injected by the AWS ALB so we get the
    # real client IP rather than the load balancer's private IP.
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        visitor_ip = forwarded_for.split(",")[0].strip()
    else:
        visitor_ip = request.remote_addr

    return jsonify(
        {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "ip": visitor_ip,
        }
    )


if __name__ == "__main__":
    # Only used for local development — gunicorn is used in the container.
    app.run(host="0.0.0.0", port=8080)
