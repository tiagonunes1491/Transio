# Stage 1: Use a lighter Alpine-based Python image
FROM python:3.13-alpine3.21 as builder

# Set environment variables to prevent Python from writing .pyc files and to keep output unbuffered
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set the working directory in the container
WORKDIR /opt/app

# Alpine may need different build dependencies
RUN apk add --no-cache gcc musl-dev

# Copy the requirements file into the container
COPY requirements.txt .

# Install Python dependencies into a virtual environment within the image
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir -r requirements.txt

# Explicitly upgrade pip and setuptools within the virtual environment
RUN /opt/venv/bin/pip install --no-cache-dir --upgrade pip
RUN /opt/venv/bin/pip install --no-cache-dir --upgrade setuptools

# Stage 2: Build the final, leaner image
FROM python:3.13-alpine3.21 as final

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set the working directory
WORKDIR /opt/app

# Copy the virtual environment from the builder stage
COPY --from=builder /opt/venv /opt/venv

# Update packages - Alpine uses apk instead of apt-get
RUN apk update && apk upgrade

# Copy the application code from your backend directory into the container
COPY ./app ./app
COPY config.py .
COPY __init__.py /opt/app/

# Install curl for healthcheck using Alpine's package manager
RUN apk add --no-cache curl

# Make sure the application runs with the venv Python
ENV PATH="/opt/venv/bin:$PATH"

## Create non-root user and group using Alpine's syntax
RUN adduser -D appuser
USER appuser

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

# Healthcheck to ensure the application is running
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD curl -f http://localhost:5000/health || exit 1

# The command to run your application.
# flask run --host=0.0.0.0 makes the server accessible from outside the container.
# Using a production-grade WSGI server like Gunicorn is recommended for actual production.
# For now, `flask run` is fine for development containerization.
ENV PYTHONPATH=/opt/app
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]