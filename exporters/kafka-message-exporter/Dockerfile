# DHI-hardened kafka-message-exporter (obsrv custom node exporter).
# Build deps on DHI node-alpine-dev (npm), run on the minimal hardened node runtime.
FROM dhi.io/node:22-alpine3.22-dev AS build
WORKDIR /opt/app
COPY package.json package-lock.json* ./
RUN npm install --omit=dev --no-audit --no-fund

FROM dhi.io/node:22-alpine3.22
WORKDIR /opt/app
COPY --from=build /opt/app/node_modules /opt/app/node_modules
COPY . .
ENV DEBUG=*
CMD ["node", "./bin/www"]
