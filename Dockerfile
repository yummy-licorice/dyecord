FROM nimlang/nim:latest

WORKDIR /dyecord

COPY dyecord.nimble ./ 

RUN nimble install -d -y

COPY . .

CMD [ "nimble", "r" ]
