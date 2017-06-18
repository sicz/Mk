ARG BASEIMAGE_NAME
ARG BASEIMAGE_TAG
FROM ${BASEIMAGE_NAME}:${BASEIMAGE_TAG}

ARG DOCKER_IMAGE_NAME
ARG DOCKER_TAG
ARG DOCKER_DESCRIPTION
ARG DOCKER_PROJECT_URL
ARG BUILD_DATE
ARG GITHUB_URL
ARG VCS_REF

LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="${DOCKER_IMAGE_NAME}"
LABEL org.label-schema.version="${DOCKER_TAG}"
LABEL org.label-schema.description="${DOCKER_DESCRIPTION}"
LABEL org.label-schema.url="${DOCKER_PROJECT_URL}"
LABEL org.label-schema.vcs-url="${GITHUB_URL}"
LABEL org.label-schema.vcs-ref="${VCS_REF}"
LABEL org.label-schema.build-date="${BUILD_DATE}"

COPY config /

ENV DOCKER_COMMAND="[*COMMAND*]"
CMD ["[*COMMAND*]"]
