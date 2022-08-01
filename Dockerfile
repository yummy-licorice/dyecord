FROM nimlang/nim:latest

WORKDIR /dyecord

COPY dyecord.nimble ./ 

RUN nimble i

COPY . .

CMD [ "./dyecord" ]
