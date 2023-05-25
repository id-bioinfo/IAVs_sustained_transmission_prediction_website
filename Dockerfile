FROM node:latest

WORKDIR /code

COPY ./package.json ./
COPY ./package-lock.json ./
RUN npm install

COPY ./ /code

ENTRYPOINT [ "npm" ]

CMD ["run", "dev"]