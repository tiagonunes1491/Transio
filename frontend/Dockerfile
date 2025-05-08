# Use an official Nginx image. 'alpine' variants are lightweight.
FROM nginx:1.25-alpine

# The Nginx configuration file we created (nginx.conf) will define how Nginx serves our content.
# We copy it into the standard Nginx configuration directory, naming it default.conf.
# This will effectively replace or become the default server configuration.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Our static frontend files (index.html, style.css, script.js) are in the 'static' subdirectory.
# We need to copy these into the directory that Nginx is configured to serve files from.
# In our nginx.conf, we set `root /usr/share/nginx/html;`.
COPY ./static /usr/share/nginx/html

# Expose port 80, which is what Nginx is listening on according to our nginx.conf.
# When we run this container, we can map this internal port 80 to a port on our host machine.
EXPOSE 80

# The base Nginx image already has a CMD to start Nginx,
# typically ["nginx", "-g", "daemon off;"]. So, we don't need to specify it here
# unless we want to override the default behavior.