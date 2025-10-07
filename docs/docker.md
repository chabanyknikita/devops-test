# 🐳 Dockerfile Documentation

## Objective

This Dockerfile is designed to create an optimized, secure, and production-ready container image for a **NestJS** application.  
The approach follows best practices for Node.js containerization, including multi-stage builds, non-root execution, and minimized image size.

---

## 🎯 Key Requirements

- Use **official Node.js base images**  
- Implement a **multi-stage build** to separate build-time and runtime dependencies  
- **Minimize final image size**  
- **Run as a non-root user** for security  
- Handle **Node.js dependencies** correctly (`npm ci`)  
- Use a proper **.dockerignore** file to exclude unnecessary files

---

## 🏗️ Multi-stage Dockerfile

```dockerfile
# ---- Build Stage ----
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files and install all dependencies
COPY package*.json ./
RUN npm ci

# Copy source code
COPY . .

# Build NestJS project
RUN npm run build


# ---- Production Stage ----
FROM node:18-alpine AS production

# Create non-root user and group
RUN addgroup -g 1001 -S nodejs \
  && adduser -S nestjs -u 1001 -G nodejs

# Set working directory
WORKDIR /app

# Copy only required files and install production dependencies
COPY --chown=nestjs:nodejs package*.json ./
RUN npm ci --only=production --ignore-scripts \
  && npm cache clean --force

# Copy compiled application from the builder stage
COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist

# Switch to non-root user
USER nestjs

# Expose the application port
EXPOSE 3000

# Start the application
CMD ["node", "dist/main"]
```

---

## 🧹 .dockerignore

This file ensures that unnecessary files are not copied into the image, keeping it small and clean.

```.dockerignore
node_modules
dist
.git
.env
Dockerfile
docker-compose.yml
npm-debug.log
```

---

## 🔒 Security Highlights

- Uses Alpine Linux for minimal attack surface
- Runs as non-root user (nestjs)
- Installs only production dependencies
- Cleans up npm cache to reduce image size
- Uses multi-stage builds to avoid including dev tools in final image