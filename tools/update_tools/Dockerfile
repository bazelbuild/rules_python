FROM gcr.io/gcp-runtimes/ubuntu_16_0_4:latest

# Install Bazel (https://docs.bazel.build/versions/master/install-ubuntu.html)
RUN apt-get update -y && apt-get install openjdk-8-jdk wget git unzip build-essential -y
RUN wget https://github.com/bazelbuild/bazel/releases/download/0.24.0/bazel-0.24.0-installer-linux-x86_64.sh -O /tmp/bazel-installer.sh
RUN chmod +x /tmp/bazel-installer.sh && /tmp/bazel-installer.sh
RUN bazel help info >/dev/null 2>&1

# Install Python 2.7.12
RUN apt-get install python -y

# Build par files.  We have a source and work directory to avoid
# stomping on other files as root.
CMD cp -r /opt/rules_python_source /opt/rules_python && \
    cd /opt/rules_python && \
    bazel clean && \
    bazel build //rules_python:piptool.par //rules_python:whltool.par && \
    cp bazel-bin/rules_python/piptool.par bazel-bin/rules_python/whltool.par /opt/rules_python_source/tools/ && \
    chown --reference=/opt/rules_python_source/update_tools.sh /opt/rules_python_source/tools/piptool.par /opt/rules_python_source/tools/whltool.par
