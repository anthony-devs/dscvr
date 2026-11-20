# DSCVR landing site (Next.js) for Cloud Run.
FROM node:20-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build && npm prune --omit=dev

FROM node:20-slim
WORKDIR /app
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 PORT=8080
COPY --from=build /app ./
EXPOSE 8080
CMD ["sh", "-c", "npx next start -p ${PORT:-8080}"]
