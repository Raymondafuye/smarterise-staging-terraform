#!/bin/bash
docker build -t lambda-layer-builder .
docker run --rm -v $(pwd):/out lambda-layer-builder cp /python_packages_layer.zip /out/
mv python_packages_layer.zip ../python_packages_layer.zip
