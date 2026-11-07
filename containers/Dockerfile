FROM mcr.microsoft.com/dotnet/sdk:10.0

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    NUGET_PACKAGES=/tmp/nuget-packages

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      xvfb xauth zip file libx11-6 libx11-xcb1 libxrandr2 \
      libfontconfig1 libfreetype6 libxi6 libxcursor1 libxinerama1 \
      libgl1 libice6 libsm6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY src/ /workspace/src/
COPY tests/ /workspace/tests/
COPY scripts/container-release-gate.sh /workspace/scripts/container-release-gate.sh
COPY global.json LICENSE THIRD_PARTY_NOTICES.md /workspace/

ENTRYPOINT ["timeout", "25m", "bash", "/workspace/scripts/container-release-gate.sh"]
