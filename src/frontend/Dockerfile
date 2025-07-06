# Use an official Nginx image. 'alpine' variants are lightweight.
FROM nginx:1.28-alpine

# Update the local installed packages to the latest versions.
RUN apk update && apk upgrade

# Install curl for health checks
RUN apk add --no-cache curl

# Remove any existing pid directive from the main config file
# This uses sed to delete ('d') lines starting from the beginning ('^') with 'pid '
# This is important because the default Nginx image uses a PID file in a privileged location.
RUN sed -i '/^pid /d' /etc/nginx/nginx.conf

# Explicitly set the PID file path in the main config by echoing it
RUN echo "pid /tmp/nginx.pid;" >> /etc/nginx/nginx.conf

# Copy the Nginx configuration file we created...
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Our static frontend files...
COPY ./static /usr/share/nginx/html

# Give the nginx user ownership of cache directories it needs to write to
RUN chown -R nginx:nginx /var/cache/nginx

# Expose the new non-privileged port Nginx will listen on.
EXPOSE 8080

# Add HEALTHCHECK instruction using curl instead of nc
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Switch to the non-root 'nginx' user.
USER nginx

# The base Nginx image already has a CMD to start Nginx,
CMD ["nginx", "-g", "daemon off;"]