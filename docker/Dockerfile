FROM edgebuilds.azurecr.io/azedge-vsts-agent-deps-armv7hf:latest
#FROM microsoft/dotnet:2.0.0-preview2-runtime-stretch

WORKDIR /app
COPY ./bin/ ./bin/

# Install dependencies
ARG ARCH=armv7l
ARG NODE_VERSION=v6.10.3

RUN mkdir ./externals/tee -p \
 && touch ./externals/tee/license.html \
 && mkdir ./externals/node \
 && curl -SL https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-$ARCH.tar.gz --output node.tar.gz \
 && tar -xzf node.tar.gz \
 && mv ./node-$NODE_VERSION-linux-$ARCH/ -T ./externals/node/ \
 && rm node.tar.gz

CMD dotnet ./bin/Agent.Listener.dll configure \
      --unattended \
      --agent "${VSTS_AGENT:-$(hostname)}" \
      --url "https://${VSTS_ACCOUNT:-msazure}.visualstudio.com" \
      --auth PAT \
      --token "${VSTS_TOKEN}" \
      --pool "${VSTS_POOL:-Azure-IoT-Edge-Core}" \
      --work "${VSTS_WORK:-_work}" \
      --replace \
 && dotnet ./bin/Agent.Listener.dll run
