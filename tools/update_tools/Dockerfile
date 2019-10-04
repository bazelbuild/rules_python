FROM gcr.io/gcp-runtimes/ubuntu_16_0_4:latest

# Install Bazel (https://docs.bazel.build/versions/master/install-ubuntu.html#install-with-installer-ubuntu).
RUN apt-get update -y && apt-get install -y \
    # The JDK requirement is from the instructions for the bazel apt package,
    # which we're not using here, but let's be safe.
    openjdk-8-jdk \
    # These requirements are from the link above.
    pkg-config zip g++ zlib1g-dev unzip python3 \
    # And why should python3 have all the fun?
    python \
    # We also need git for git_repository to work. Maybe these other ones too.
    git unzip build-essential \
    # And wget for the below command.
    wget

RUN wget https://github.com/bazelbuild/bazel/releases/download/0.28.0/bazel-0.28.0-installer-linux-x86_64.sh -O /tmp/bazel-installer.sh
RUN chmod +x /tmp/bazel-installer.sh && /tmp/bazel-installer.sh

# Sanity check the install.
RUN bazel help info >/dev/null 2>&1

# Build par files.  We have a source and work directory to avoid stomping on
# other files as root.
CMD cp -r /opt/rules_python_source /opt/rules_python && \
    cd /opt/rules_python && \
    bazel clean && \
    bazel build //packaging:piptool.par //packaging:whltool.par \
        # This works around a bug in git_repository to give us better debugging
        # if there's an error.
        # TODO(brandjon): Remove this once we're using Bazel 0.29, which
        # contains the fix.
        --incompatible_string_join_requires_strings=false && \
    cp bazel-bin/packaging/piptool.par bazel-bin/packaging/whltool.par /opt/rules_python_source/tools/ && \
    chown --reference=/opt/rules_python_source/update_tools.sh /opt/rules_python_source/tools/piptool.par /opt/rules_python_source/tools/whltool.par
