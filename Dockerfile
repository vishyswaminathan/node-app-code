# --- Build stage ---
    FROM node:20-slim as build
    LABEL "Author"="Vishy"
    LABEL "Project"="nodejs"
    
    # Update and upgrade base OS packages to reduce CVEs
    RUN apt-get update && apt-get upgrade -y && apt-get clean && rm -rf /var/lib/apt/lists/*
    
    # Set working directory and install dependencies
    WORKDIR /app
    COPY node/ /app/
    
    # Install only production dependencies
    RUN npm install --omit=dev
    
    # --- Final stage (distroless) ---
    FROM gcr.io/distroless/nodejs-debian12
    
    # Copy app from build stage
    COPY --from=build /app /app
    
    WORKDIR /app
    
    EXPOSE 8080
    
    # Run the Node.js app
    CMD ["app.js"]
    
