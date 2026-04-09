# --------- Build Stage ---------
FROM node:20-alpine AS builder

# Install openssl for Prisma
RUN apk add --no-cache openssl libc6-compat

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY backend/package*.json ./backend/
COPY frontend/package*.json ./frontend/

# Install root dependencies
RUN npm install

# Build Frontend
COPY frontend ./frontend/
RUN cd frontend && npm run build

# Build Backend
COPY backend ./backend/
RUN cd backend && npx prisma generate && npm run build

# --------- Production Stage ---------
FROM node:20-alpine AS production

# Install openssl for Prisma
RUN apk add --no-cache openssl

WORKDIR /app

# Copy root package files and ALL node_modules (including hoisted ones)
COPY package*.json ./
COPY --from=builder /app/node_modules ./node_modules

# Copy built backend
COPY --from=builder /app/backend/dist ./backend/dist
COPY --from=builder /app/backend/node_modules ./backend/node_modules
COPY --from=builder /app/backend/package*.json ./backend/
COPY --from=builder /app/backend/prisma ./backend/prisma

# Copy built frontend (so backend can serve it)
COPY --from=builder /app/frontend/dist ./frontend/dist

ENV NODE_ENV=production
ENV PORT=4000

EXPOSE 4000

# Run migrations and start the server
# Using -w backend ensures it runs in the correct workspace context
CMD ["sh", "-c", "npx prisma migrate deploy --schema=./backend/prisma/schema.prisma && node backend/dist/index.js"]
