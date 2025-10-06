FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

RUN npm run build


FROM node:18-alpine AS production

RUN addgroup -g 1001 -S nodejs \
  && adduser -S nestjs -u 1001 -G nodejs

WORKDIR /app
COPY --chown=nestjs:nodejs package*.json ./

RUN npm ci --only=production --ignore-scripts \
  && npm cache clean --force

COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist
USER nestjs
EXPOSE 3000
CMD ["node", "dist/main"]
