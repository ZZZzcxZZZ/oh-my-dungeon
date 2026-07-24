FROM node:22-alpine AS build

WORKDIR /app/apps/server_nest

COPY apps/server_nest/package.json apps/server_nest/package-lock.json ./
RUN npm ci --ignore-scripts

COPY apps/server_nest ./
RUN npx prisma generate && npm run build

FROM node:22-alpine AS runtime

WORKDIR /app/apps/server_nest
ENV NODE_ENV=production

# 复制 package 元数据并安装生产依赖, 排除 devDependencies (eslint/jest/ts-jest 等).
COPY --from=build /app/apps/server_nest/package.json ./
COPY --from=build /app/apps/server_nest/package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

# 复制 Prisma 资源 (含 prisma.config.ts) 与编译产物.
COPY --from=build /app/apps/server_nest/prisma ./prisma
COPY --from=build /app/apps/server_nest/prisma.config.ts ./
COPY --from=build /app/apps/server_nest/dist ./dist

# node:22-alpine 自带非 root 用户 `node`, 切换以避免容器以 root 运行.
RUN mkdir -p /app/uploads && chown -R node:node /app
USER node

EXPOSE 3000

# 健康检查: 让编排层能在 unhealthy 时自动重启容器.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["sh", "-c", "npx prisma migrate deploy && npx prisma db seed && node dist/main.js"]
