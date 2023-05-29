FROM node:latest

WORKDIR /code

COPY ./package.json ./
COPY ./package-lock.json ./
RUN npm install

COPY ./ /code

EXPOSE 8080

ENTRYPOINT [ "npm" ]

CMD ["run", "dev"]