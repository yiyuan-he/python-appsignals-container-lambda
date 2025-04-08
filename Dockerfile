FROM public.ecr.aws/lambda/python:3.13

# Copy function code
COPY app.py ${LAMBDA_TASK_ROOT}

# Install unzip and wget utilities
RUN dnf install -y unzip wget

# Download the OpenTelemetry Layer with AppSignals Support
RUN wget https://github.com/aws-observability/aws-otel-python-instrumentation/releases/latest/download/layer.zip -O /tmp/layer.zip

# Extract and include Lambda layer contents
COPY layer.zip /tmp/
RUN mkdir -p /opt && \
    unzip /tmp/layer.zip -d /opt/ && \
    chmod -R 755 /opt/ && \
    rm /tmp/layer.zip

# Set the CMD to your handler
CMD [ "app.lambda_handler" ]
