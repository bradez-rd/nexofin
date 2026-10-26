# Multi-stage Dockerfile para NexoFin AI Backend
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.json ./

RUN npm ci

COPY src/ ./src/
COPY db/ ./db/

RUN npm run build

# Imagen de producción liviana
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --only=production

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/db ./db

EXPOSE 3000

CMD ["node", "dist/server.js"]
