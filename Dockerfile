#
# Dockerfile - TensorFlow GPU
#
# - Build
# docker build --rm -t ruo91/tensorflow:latest-gpu .
#
# - Run
# nvidia-docker run -d --name="tensorflow" -h "tensorflow" -p 8888:8888 ruo91/tensorflow:latest-gpu
#
# Use the base images
FROM centos:centos7
LABEL maintainer="Yongbok Kim <ruo91@yongbok.net>"

# The latest package
#RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Base.repo \
# && sed -i 's/#baseurl\=http\:\/\/mirror.centos.org/baseurl\=http\:\/\/ftp.daumkakao.com/g' /etc/yum.repos.d/CentOS-Base.repo
RUN yum clean all && yum repolist && yum install -y nano net-tools curl epel-release

#CUDA Runtime
RUN NVIDIA_GPGKEY_SUM=d1be581509378368edeec8c1eb2958702feedf3bc3d17011adbf24efacce4ab5 && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/7fa2af80.pub | sed '/^Version/d' > /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA && \
    echo "$NVIDIA_GPGKEY_SUM  /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA" | sha256sum -c --strict -
COPY conf/cuda.repo /etc/yum.repos.d/cuda.repo

ENV CUDA_VERSION 8.0.61

ENV CUDA_PKG_VERSION 8-0-$CUDA_VERSION-1
RUN yum install -y \
        cuda-nvrtc-$CUDA_PKG_VERSION \
        cuda-nvgraph-$CUDA_PKG_VERSION \
        cuda-cusolver-$CUDA_PKG_VERSION \
        cuda-cublas-8-0-8.0.61.2-1 \
        cuda-cufft-$CUDA_PKG_VERSION \
        cuda-curand-$CUDA_PKG_VERSION \
        cuda-cusparse-$CUDA_PKG_VERSION \
        cuda-npp-$CUDA_PKG_VERSION \
        cuda-cudart-$CUDA_PKG_VERSION && \
    ln -s cuda-8.0 /usr/local/cuda && \
    rm -rf /var/cache/yum/*

# nvidia-docker 1.0
LABEL com.nvidia.volumes.needed="nvidia_driver"
LABEL com.nvidia.cuda.version="${CUDA_VERSION}"

RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV NVIDIA_REQUIRE_CUDA "cuda>=8.0"

# CUDA
RUN yum install -y cuda-8-0

# CUDNN
ENV CUDNN_VERSION 6.0.21
LABEL com.nvidia.cudnn.version="${CUDNN_VERSION}"

# cuDNN license: https://developer.nvidia.com/cudnn/license_agreement
RUN CUDNN_DOWNLOAD_SUM=9b09110af48c9a4d7b6344eb4b3e344daa84987ed6177d5c44319732f3bb7f9c && \
    curl -fsSL http://developer.download.nvidia.com/compute/redist/cudnn/v6.0/cudnn-8.0-linux-x64-v6.0.tgz -O && \
    echo "$CUDNN_DOWNLOAD_SUM  cudnn-8.0-linux-x64-v6.0.tgz" | sha256sum -c - && \
    tar --no-same-owner -xzf cudnn-8.0-linux-x64-v6.0.tgz -C /usr/local --wildcards 'cuda/lib64/libcudnn.so.*' && \
    rm cudnn-8.0-linux-x64-v6.0.tgz && \
    ldconfig

# TensorFlow
RUN yum install -y gcc gcc-c++ python34-pip python34-devel atlas atlas-devel gcc-gfortran openssl-devel libffi-devel

# use pip3
RUN pip3 install --upgrade pip \
  && pip3 install --upgrade virtualenv \
  && virtualenv --system-site-packages ~/venvs/tensorflow \
  && source ~/venvs/tensorflow/bin/activate \
  && pip3 install --upgrade numpy scipy wheel cryptography \
  && pip3 install tensorflow-gpu \
  && pip3 install jupyter \
  && pip3 install matplotlib

# Set up our notebook config.
COPY conf/jupyter_notebook_config.py /root/.jupyter/

# Copy sample notebooks.
COPY conf/notebooks /opt/notebooks

# Jupyter has issues with being run directly:
#   https://github.com/ipython/ipython/issues/7062
# We just add a little wrapper script.
COPY conf/run_jupyter.sh /

# PATH
ENV CUDA_HOME /usr/local/cuda
ENV TF_HOME $HOME/venvs/tensorflow/bin
ENV PATH $PATH:$TF_HOME:$CUDA_HOME

# For CUDA profiling, TensorFlow requires CUPTI.
ENV LD_LIBRARY_PATH /usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:$LD_LIBRARY_PATH

# Port
# TensorBoard: 6006
# IPython: 8888
EXPOSE 6006 8888

# Work Directory
WORKDIR "/opt/notebooks"

# Execute
CMD ["/run_jupyter.sh", "--allow-root"]
