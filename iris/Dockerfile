# ARG IMAGE=intersystemsdc/irishealth-community:latest
ARG IMAGE=containers.intersystems.com/intersystems/irishealth-community-arm64:2023.2.0.227.0
FROM $IMAGE

WORKDIR /home/irisowner/irisdev
#RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisapp

# copy files to image
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} ssl ssl
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} data/fhir /opt/irisapp/fhirdata

# run iris and initial 
RUN --mount=type=bind,src=.,dst=. \
    iris start IRIS && \
	iris session IRIS < iris.script && \
    iris stop IRIS quietly
