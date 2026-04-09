# --------- Build Stage ---------
FROM node:20-alpine AS builder

# Install build dependencies
RUN apk add --no-cache openssl libc6-compat

WORKDIR /app

# Copy root package files
COPY package*.json ./
COPY backend/package*.json ./backend/
COPY frontend/package*.json ./frontend/

# Install ALL dependencies (including dev)
RUN npm install

# Copy source and build everything
COPY . .
RUN cd frontend && npm run build
RUN cd backend && npx prisma generate && npm run build

# --------- Production Stage ---------
FROM node:20-alpine AS production

RUN apk add --no-cache openssl

WORKDIR /app

# Copy root package files
COPY package*.json ./
COPY backend/package*.json ./backend/

# Install ONLY production dependencies
# This keeps the image small and avoids hoisting issues
RUN npm install --omit=dev

# Copy generated Prisma client from builder
COPY --from=builder /app/backend/node_modules/.prisma ./backend/node_modules/.prisma
COPY --from=builder /app/backend/node_modules/@prisma ./backend/node_modules/@prisma

# Copy built assets
COPY --from=builder /app/backend/dist ./backend/dist
COPY --from=builder /app/backend/prisma ./backend/prisma
COPY --from=builder /app/frontend/dist ./frontend/dist

ENV NODE_ENV=production
ENV PORT=4000

EXPOSE 4000

# Final entrypoint script
CMD ["sh", "-c", "cd backend && npx prisma migrate deploy && node dist/index.js"]
