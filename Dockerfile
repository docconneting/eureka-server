# 1. Java 17 기반의 가벼운 이미지를 사용
FROM openjdk:17-jdk-slim

# 2. JAR 파일을 이미지에 복사 (ARG로 전달받거나 직접 지정)
ARG JAR_FILE=build/libs/*.jar
COPY ${JAR_FILE} app.jar

# 3. 애플리케이션 실행
ENTRYPOINT ["java", "-jar", "/app.jar"]
