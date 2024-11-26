FROM --platform=linux/amd64 node:20.10-alpine
WORKDIR /opt/app
COPY ./package.json .
RUN npm install --silent
COPY . .
CMD ["npm", "run", "start"]