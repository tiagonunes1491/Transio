# Stage 1: Use an official Python runtime as a parent image
FROM python:3.11-slim as builder

# Set environment variables to prevent Python from writing .pyc files and to keep output unbuffered
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set the working directory in the container
WORKDIR /opt/app

# Install build dependencies if any (sometimes needed for certain packages)
# RUN apt-get update && apt-get install -y --no-install-recommends gcc

# Copy the requirements file into the container
COPY requirements.txt .

# Install Python dependencies into a virtual environment within the image
# Using a virtual environment here is good practice even inside a container
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Build the final, leaner image
FROM python:3.11-slim as final

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set the working directory
WORKDIR /opt/app

# Copy the virtual environment from the builder stage
COPY --from=builder /opt/venv /opt/venv

# Copy the application code from your backend directory into the container
# This includes the 'app' directory and 'config.py'.
# IMPORTANT: We are NOT copying the .env file. Sensitive configurations like
# MASTER_ENCRYPTION_KEY will be passed as environment variables when running the container (e.g., via docker-compose).
COPY ./app ./app
COPY config.py .
COPY __init__.py /opt/app/

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && apt-get clean

# Make sure the application runs with the venv Python
ENV PATH="/opt/venv/bin:$PATH"

# Expose the port the app runs on (Flask default is 5000)
EXPOSE 5000

# Define environment variables needed by Flask and your app.
# These will be used by config.py if a .env file isn't present.
# FLASK_APP tells Flask where your application instance is.
# FLASK_DEBUG can be set to False for production builds, but True is fine for now.
# The MASTER_ENCRYPTION_KEY MUST be provided when running the container.
ENV FLASK_APP=app.main
ENV FLASK_DEBUG=True
# Example: ENV MASTER_ENCRYPTION_KEY="your_key_here_from_docker_compose_or_env" (but set it at runtime)

# The command to run your application.
# flask run --host=0.0.0.0 makes the server accessible from outside the container.
# Using a production-grade WSGI server like Gunicorn is recommended for actual production.
# For now, `flask run` is fine for development containerization.
ENV PYTHONPATH=/opt/app
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]