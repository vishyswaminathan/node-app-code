# --- Build stage ---
    FROM node:20-slim AS build
    LABEL "Author"="Vishy"
    LABEL "Project"="nodejs"
    
    # Update base OS packages and clean up
    RUN apt-get update && apt-get upgrade -y && apt-get clean && rm -rf /var/lib/apt/lists/*
    
    WORKDIR /app
    
    # Copy app source code (adjust path if needed)
    COPY . .
    
    # Install only production dependencies
    RUN npm install --omit=dev
    
    # --- Final stage (distroless) ---
    FROM gcr.io/distroless/nodejs:latest
    
    WORKDIR /app
    
    # Copy built app from the build stage
    COPY --from=build /app /app
    
    EXPOSE 8080
    
    # Run the Node.js app
    CMD ["node", "hello.js"]
    