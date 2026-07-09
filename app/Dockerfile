# ── Build stage ───────────────────────────────────────────────────────────────
# Install dependencies separately so the final image contains no build tooling.
FROM python:3.13-alpine AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Runtime stage ─────────────────────────────────────────────────────────────
FROM python:3.13-alpine

# Create a non-root user/group as required by the challenge spec.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only the installed packages from the builder — no pip, no cache.
COPY --from=builder /install /usr/local

COPY main.py .

# Drop privileges before the process starts.
USER appuser

EXPOSE 8080

# gunicorn is a production-grade WSGI server; avoids Flask's dev server.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "main:app"]
