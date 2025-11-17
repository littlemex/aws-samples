FROM public.ecr.aws/docker/library/node:20-alpine

# Set working directory
WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Copy package files
COPY --chown=nextjs:nodejs package*.json ./

# Install dependencies (including devDependencies for tsx)
RUN npm ci && \
    npm cache clean --force

# Copy source code and configuration
COPY --chown=nextjs:nodejs tsconfig.json ./
COPY --chown=nextjs:nodejs src ./src
COPY --chown=nextjs:nodejs .env.example ./.env

USER nextjs

# Expose port 8080 as required by AgentCore Runtime
EXPOSE 8080

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8080
ENV HOST=0.0.0.0

# Health check for AgentCore Runtime
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "const http = require('http'); http.get('http://localhost:8080/ping', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start the application with tsx
CMD ["npx", "tsx", "src/index.ts"]
