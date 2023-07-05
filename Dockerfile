FROM eclipse-temurin:17.0.7_7-jdk as cruisecontrol
ARG CRUISE_CONTROL_VERSION
WORKDIR /
USER root
RUN \
  set -xe; \
  apt-get update -qq \
  && apt-get install -qq --no-install-recommends \
    git ca-certificates
RUN \
  set -xe; \
  git clone \
    --branch ${CRUISE_CONTROL_VERSION} \
    --depth 1 \
    https://github.com/linkedin/cruise-control.git \
  && cd cruise-control \
  && git rev-parse HEAD \
  && ./gradlew jar copyDependantLibs \
  && mv -v /cruise-control/cruise-control/build/libs/cruise-control-*.jar \
    /cruise-control/cruise-control/build/libs/cruise-control.jar \
  && mv -v /cruise-control/cruise-control/build/dependant-libs/cruise-control-metrics-reporter-*.jar \
    /cruise-control/cruise-control/build/dependant-libs/cruise-control-metrics-reporter.jar

FROM node:20.3.1-buster as cruisecontrol-ui
ARG CRUISE_CONTROL_UI_GIT_REF
WORKDIR /
RUN \
  set -xe; \
  git clone \
    https://github.com/linkedin/cruise-control-ui.git \
  && cd cruise-control-ui \
  && git checkout ${CRUISE_CONTROL_UI_GIT_REF} \
  && git rev-parse HEAD \
  && npm install \
  && npm run build

FROM eclipse-temurin:17.0.7_7-jre
ENV CRUISE_CONTROL_LIBS="/var/lib/cruise-control-ext-libs/*"
ENV CLASSPATH="${CRUISE_CONTROL_LIBS}"
RUN \
  set -xe; \
  mkdir -p /opt/cruise-control \
           /opt/cruise-control/cruise-control-ui \
           ${CRUISE_CONTROL_LIBS}
COPY --from=cruisecontrol /cruise-control/cruise-control/build/libs/cruise-control.jar /opt/cruise-control/cruise-control/build/libs/cruise-control.jar
COPY --from=cruisecontrol /cruise-control/config /opt/cruise-control/config
COPY --from=cruisecontrol /cruise-control/kafka-cruise-control-start.sh /opt/cruise-control/
COPY --from=cruisecontrol /cruise-control/cruise-control/build/dependant-libs /opt/cruise-control/cruise-control/build/dependant-libs
COPY --from=cruisecontrol-ui /cruise-control-ui/dist /opt/cruise-control/cruise-control-ui/dist
COPY opt/cruise-control /opt/cruise-control/
RUN \
  set -xe; \
  echo "local,localhost,/kafkacruisecontrol" > /opt/cruise-control/cruise-control-ui/dist/static/config.csv \
  && chmod +x /opt/cruise-control/start.sh
EXPOSE 8090
CMD ["/opt/cruise-control/start.sh"]
LABEL org.opencontainers.artifact.description="Linkedin's Cruise Control (https://github.com/linkedin/cruise-control)"
LABEL org.opencontainers.image.url="https://github.com/banzaicloud/docker-cruise-control"
LABEL org.opencontainers.image.documentation="https://github.com/banzaicloud/docker-cruise-control"
LABEL org.opencontainers.image.source="https://github.com/banzaicloud/docker-cruise-control"
LABEL org.opencontainers.image.title="Linkedin's Cruise Control"
LABEL org.opencontainers.image.description="Cruise Control container image built for Koperator (https://github.com/banzaicloud/koperator)"
LABEL org.opencontainers.image.vendor="Cisco Systems"
