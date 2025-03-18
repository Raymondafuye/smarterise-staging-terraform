#!/bin/bash

# Set working directory
LAYER_DIR="infra_staging/lambda/python_packages_layer"

# Create directory structure
mkdir -p "${LAYER_DIR}"
cd "${LAYER_DIR}"

# Create requirements.txt
cat > requirements.txt << EOL
psycopg2-binary==2.9.9
numpy==1.24.4
EOL

# Create Dockerfile
cat > Dockerfile << EOL
FROM --platform=linux/x86_64 amazonlinux:2

RUN yum update -y && \
    yum groupinstall -y "Development Tools" && \
    yum install -y python39 python39-devel python39-pip

RUN mkdir -p /output/python/lib/python3.9/site-packages

COPY requirements.txt /requirements.txt

RUN python3.9 -m pip install --upgrade pip && \
    python3.9 -m pip install -r /requirements.txt -t /output/python/lib/python3.9/site-packages

RUN cd /output && zip -r /python_packages_layer.zip .
EOL

# Create build script
cat > build_layer.sh << EOL
#!/bin/bash
docker build -t lambda-layer-builder .
docker run --rm -v \$(pwd):/out lambda-layer-builder cp /python_packages_layer.zip /out/
mv python_packages_layer.zip ../python_packages_layer.zip
EOL

# Make build script executable
chmod +x build_layer.sh

# Build the layer
./build_layer.sh

echo "Layer created successfully!"
