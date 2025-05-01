name: Deploy Eureka

on:
  push:
    branches:
      - feat/cicd  # 이 브랜치에 push될 때마다 작동
  workflow_dispatch:  # 수동 실행도 가능하게


env:
  AWS_REGION: ap-northeast-2
  IMAGE_NAME: eureka-service

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build Docker Image
        run: |
          cd eureka-service
          ./gradlew bootJar
          docker build -t $IMAGE_NAME:latest .

      - name: Tag and Push to ECR
        run: |
          docker tag $IMAGE_NAME:latest ${{ steps.login-ecr.outputs.registry }}/$IMAGE_NAME
          docker push ${{ steps.login-ecr.outputs.registry }}/$IMAGE_NAME

      - name: Prepare SSH and .env
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DOCCONNETING_SSH_KEY }}" | base64 --decode > ~/.ssh/docconneting.pem
          chmod 600 ~/.ssh/docconneting.pem

          cat <<EOF > ~/.ssh/config
          Host bastion
            HostName ${{ secrets.BASTION_HOST }}
            User ubuntu
            IdentityFile ~/.ssh/docconneting.pem
            StrictHostKeyChecking no

          Host eureka
            HostName ${{ secrets.EUREKA_PRIVATE_IP }}
            User ubuntu
            IdentityFile ~/.ssh/docconneting.pem
            ProxyJump bastion
            StrictHostKeyChecking no
          EOF

          ssh eureka "echo 'SPRING_PROFILES_ACTIVE=prod' > ~/eureka.env"

      - name: Deploy to EC2
        run: |
          ssh eureka <<'EOF'
            docker pull ${{ steps.login-ecr.outputs.registry }}/$IMAGE_NAME
            docker stop eureka || true && docker rm eureka || true
            docker run -d \
              --name eureka \
              --env-file ~/eureka.env \
              -p 8761:8761 \
              ${{ steps.login-ecr.outputs.registry }}/$IMAGE_NAME
          EOF
