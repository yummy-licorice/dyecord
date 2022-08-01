FROM nimlang/nim:latest

WORKDIR /dyecord

COPY . .  

RUN apt update && apt install curl
RUN nimble i

CMD [ "./dyecord" ]
