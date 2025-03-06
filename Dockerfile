FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/main.dart -o bin/proxy

FROM debian:buster-slim
COPY --from=build /app/bin/proxy /app/proxy
COPY --from=build /app/cert.pem /app/cert.pem
COPY --from=build /app/key.pem /app/key.pem

EXPOSE 8080
CMD ["/app/proxy"]