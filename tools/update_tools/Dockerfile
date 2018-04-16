FROM gcr.io/gcp-runtimes/ubuntu_16_0_4:latest

# Install Bazel (https://docs.bazel.build/versions/master/install-ubuntu.html)
RUN apt-get update -y && apt-get install openjdk-8-jdk -y
RUN echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list
RUN curl https://bazel.build/bazel-release.pub.gpg | apt-key add -
RUN apt-get update -y && apt-get install bazel -y
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

