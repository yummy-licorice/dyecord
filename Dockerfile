FROM nimlang/nim:latest

WORKDIR /dyecord

COPY dyecord.nimble ./ 

RUN nimble install -d -y && nimble build -d:ssl -d:release -d:dimscordDebug

COPY . .

CMD [ "./dyecord" ]
