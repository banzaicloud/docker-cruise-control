FROM eclipse-temurin:11.0.13_8-jdk as cruisecontrol
ARG VERSION=2.5.78
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
    --branch ${VERSION} \
    --depth 1 \
    https://github.com/linkedin/cruise-control.git \
  && cd cruise-control \
  && git rev-parse HEAD \
  && ./gradlew jar copyDependantLibs \
  && mv -v /cruise-control/cruise-control/build/libs/cruise-control-*.jar \
    /cruise-control/cruise-control/build/libs/cruise-control.jar \
  && mv -v /cruise-control/cruise-control/build/dependant-libs/cruise-control-metrics-reporter-*.jar \
    /cruise-control/cruise-control/build/dependant-libs/cruise-control-metrics-reporter.jar

FROM node:16.13.0-buster as cruisecontrol-ui
ARG BRANCH=master
ARG REF=0102593e169a2eed6dd3980b81aa7ab71af2d868
WORKDIR /
RUN \
  set -xe; \
  git clone \
    --branch ${BRANCH} \
    --depth 1 \
    https://github.com/linkedin/cruise-control-ui.git \
  && cd cruise-control-ui \
  && git checkout ${REF} \
  && git rev-parse HEAD \
  && npm install \
  && npm run build

FROM eclipse-temurin:11.0.13_8-jre
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
