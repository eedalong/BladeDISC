#!/bin/bash
# Copyright 2021 The BladeDISC Authors. All rights reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set -ex
curl -sL https://github.com/Kitware/CMake/releases/download/v3.20.0/cmake-3.20.0-linux-x86_64.sh \
    -o /tmp/cmake-install.sh && \
  chmod u+x /tmp/cmake-install.sh && \
  mkdir -p /opt/cmake && \
  /tmp/cmake-install.sh --skip-license --prefix=/opt/cmake && \
  rm /tmp/cmake-install.sh


