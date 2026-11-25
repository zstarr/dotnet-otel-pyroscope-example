# syntax=docker/dockerfile:1

# ---- Build stage ----------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore first (better layer caching): only re-runs when the csproj changes.
COPY DotNetApp.csproj ./
RUN dotnet restore DotNetApp.csproj

# Copy the rest of the source and publish a release build.
COPY . ./
RUN dotnet publish DotNetApp.csproj -c Release -o /app/publish /p:UseAppHost=false

# ---- Runtime stage --------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish ./

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && mkdir -p /opt/pyroscope \
    && PYRO_VER="1.6.1" \
    && PYRO_HOST="github.com" \
    && PYRO_PATH="grafana/pyroscope-dotnet/releases/download/pyroscope-${PYRO_VER}/pyroscope.${PYRO_VER}-glibc-x86_64.tar.gz" \
    && curl -fL "https://${PYRO_HOST}/${PYRO_PATH}" | tar -xz -C /opt/pyroscope \
    && rm -rf /var/lib/apt/lists/*

# Serve plain HTTP inside the container on 8080; TLS is terminated elsewhere.
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "DotNetApp.dll"]
