FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies (including dev for build)
RUN npm ci

# Copy source files
COPY src ./src

# Copy public files for web admin
COPY public ./public

# Build TypeScript
RUN npm run build

# Remove dev dependencies
RUN npm prune --production

# Create data directory
RUN mkdir -p /app/data

# Expose port
EXPOSE 7990

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:7990/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the server
CMD ["node", "dist/server.js"]
