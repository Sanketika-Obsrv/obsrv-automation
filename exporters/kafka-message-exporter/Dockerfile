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
# Runtime image has no shell/curl/wget (DHI hardened alpine), so this can't be a shell-form or
# curl healthcheck -- use node's own net module for a bare TCP connect check instead. Port read
# from process.env.PORT (bin/www's actual listen var) with the same 3000 fallback.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["node", "-e", "var p=process.env.PORT||3000;var s=require('net').connect(p,'127.0.0.1');s.on('connect',function(){s.end();process.exit(0)});s.on('error',function(){process.exit(1)})"]
CMD ["node", "./bin/www"]
