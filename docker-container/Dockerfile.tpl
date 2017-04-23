FROM [*BASE_IMAGE_NAME*]:%%BASE_IMAGE_TAG%%

ENV \
  org.label-schema.schema-version="1.0" \
  org.label-schema.name="%%DOCKER_PROJECT%%/%%DOCKER_NAME%%" \
  org.label-schema.description="[*One Sentence of project description goes here*]" \
  org.label-schema.build-date="%%REFRESHED_AT%%" \
  org.label-schema.url="[*PROJECT_URL*]" \
  org.label-schema.vcs-url="https://github.com/%%DOCKER_PROJECT%%/docker-%%DOCKER_NAME%%"
