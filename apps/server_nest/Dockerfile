FROM node:22-alpine AS build

WORKDIR /app/apps/server_nest

COPY apps/server_nest/package.json apps/server_nest/package-lock.json ./
RUN npm ci --ignore-scripts

COPY apps/server_nest ./
RUN npx prisma generate && npm run build

FROM node:22-alpine AS runtime

WORKDIR /app/apps/server_nest
ENV NODE_ENV=production

COPY --from=build /app/apps/server_nest/package.json ./
COPY --from=build /app/apps/server_nest/node_modules ./node_modules
COPY --from=build /app/apps/server_nest/prisma ./prisma
COPY --from=build /app/apps/server_nest/prisma.config.ts ./
COPY --from=build /app/apps/server_nest/dist ./dist

EXPOSE 3000
CMD ["sh", "-c", "npx prisma migrate deploy && npx prisma db seed && node dist/main.js"]
