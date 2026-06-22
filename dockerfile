# Base image: nginx on Alpine Linux
# Alpine is a minimal Linux distro — results in a much smaller image
# which means faster pulls, less attack surface for Trivy to flag
FROM nginx:alpine

# Remove the default nginx placeholder page
# nginx ships with a default "Welcome to nginx" index.html
# We don't want that — we want our app served instead
RUN rm -rf /usr/share/nginx/html/*

# Copy our entire app directory into nginx's web root
# The left side (app/) is relative to your build context (the repo root)
# The right side is where nginx serves files from inside the container
COPY app/ /usr/share/nginx/html/

# Tell Docker this container listens on port 80
# This is documentation — it doesn't actually open the port
# Your K8s Service manifest is what actually exposes it
EXPOSE 80

# nginx:alpine already has a default CMD that starts nginx
# so we don't need to define one — it just works