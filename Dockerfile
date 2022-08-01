FROM nimlang/nim:latest

WORKDIR /dyecord

COPY . .  

RUN nimble i

CMD [ "./dyecord" ]
