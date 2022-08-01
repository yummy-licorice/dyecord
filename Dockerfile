FROM nimlang/nim:latest

WORKDIR /dyecord

COPY . .  

RUN apt --yes update && apt --yes install curl jq
RUN nimble i

CMD [ "./dyecord" ]
