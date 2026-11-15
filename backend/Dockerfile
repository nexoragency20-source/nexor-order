FROM node:22-bookworm-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN DIRECT_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder" npx prisma generate
RUN npm run build

EXPOSE 3000

CMD ["sh", "-c", "npm run db:deploy && npm run start:prod"]
