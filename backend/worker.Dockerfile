FROM python:3.11-slim

# PrusaSlicer for headless gcode export. The Debian package is named
# "prusa-slicer" on bookworm.
RUN apt-get update \
    && apt-get install -y --no-install-recommends prusa-slicer \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["arq", "app.workers.worker.WorkerSettings"]
