pipeline {
    agent any

    tools {
        jdk 'jdk'
        nodejs 'nodejs'
    }

    environment {
        APP_REPO       = 'https://github.com/your_repo_name'
        K8S_REPO_NAME  = 'your_repo_name'
        DOCKERHUB_USER = 'your_dockerhub_username'
        SCANNER_HOME   = tool 'sonar-scanner'
        NVD_API_KEY    = credentials('NVD_API_KEY')
    }

    options {
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        // ─────────────────────────────────────────
        //  STAGE 1 - Checkout
        // ─────────────────────────────────────────
        stage('Checkout App Code') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-credentials',
                    url: "${APP_REPO}"
            }
        }

        // ─────────────────────────────────────────
        //  STAGE 2 - Set Image Tagsona
        // ─────────────────────────────────────────
        stage('Set Image Tag') {
            steps {
                script {
                    def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = "${BUILD_NUMBER}-${shortSha}"
                    echo "Image tag set to: ${env.IMAGE_TAG}"
                }
            }
        }

        // ─────────────────────────────────────────
        //  STAGE 3 - SonarQube Analysis
        // ─────────────────────────────────────────
        stage('SonarQube Analysis') {
            parallel {
                stage('Sonar - Backend') {
                    steps {
                        dir('backend') {
                            withSonarQubeEnv('sonar-server') {
                                sh '''
                                    $SCANNER_HOME/bin/sonar-scanner \
                                        -Dsonar.projectName=food-backend \
                                        -Dsonar.projectKey=food-backend \
                                        -Dsonar.sources=.
                                '''
                            }
                        }
                    }
                }
                stage('Sonar - Frontend') {
                    steps {
                        dir('frontend') {
                            withSonarQubeEnv('sonar-server') {
                                sh '''
                                    $SCANNER_HOME/bin/sonar-scanner \
                                        -Dsonar.projectName=food-frontend \
                                        -Dsonar.projectKey=food-frontend \
                                        -Dsonar.sources=.
                                '''
                            }
                        }
                    }
                }
                stage('Sonar - Admin') {
                    steps {
                        dir('admin') {
                            withSonarQubeEnv('sonar-server') {
                                sh '''
                                    $SCANNER_HOME/bin/sonar-scanner \
                                        -Dsonar.projectName=food-admin \
                                        -Dsonar.projectKey=food-admin \
                                        -Dsonar.sources=.
                                '''
                            }
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────
        //  STAGE 4 - Quality Gate
        // ─────────────────────────────────────────
        stage('Quality Gate') {
            steps {
                script {
                    // abortPipeline: false → warns but continues
                    waitForQualityGate abortPipeline: true, credentialsId: 'sonar-token'
                }
            }
        }

        // ─────────────────────────────────────────
        //  STAGE 5 - OWASP Dependency Check
        // ─────────────────────────────────────────
        stage('OWASP Dependency Check') {
            parallel {
                stage('OWASP - Backend') {
                    steps {
                        dir('backend') {
                            dependencyCheck additionalArguments: """
                                --scan ./
                                --disableYarnAudit
                                --disableNodeAudit
                                --nvdApiKey ${NVD_API_KEY}
                                --noupdate
                            """, odcInstallation: 'DP-Check'
                            dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                        }
                    }
                }
                stage('OWASP - Frontend') {
                    steps {
                        dir('frontend') {
                            dependencyCheck additionalArguments: """
                                --scan ./
                                --disableYarnAudit
                                --disableNodeAudit
                                --nvdApiKey ${NVD_API_KEY}
                                --noupdate
                            """, odcInstallation: 'DP-Check'
                            dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                        }
                    }
                }
                stage('OWASP - Admin') {
                    steps {
                        dir('admin') {
                            dependencyCheck additionalArguments: """
                                --scan ./
                                --disableYarnAudit
                                --disableNodeAudit
                                --nvdApiKey ${NVD_API_KEY}
                                --noupdate
                            """, odcInstallation: 'DP-Check'
                            dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────
        //  STAGE 6 - Trivy Filesystem Scan
        //  Scans source code before building images
        // ─────────────────────────────────────────
        stage('Trivy FS Scan') {
            steps {
                sh 'trivy fs --severity HIGH,CRITICAL . > trivy-fs-report.txt 2>&1 || true'
                archiveArtifacts artifacts: 'trivy-fs-report.txt'
            }
        }

        // ─────────────────────────────────────────
        //  STAGE 7 - Docker Login
        // ─────────────────────────────────────────
        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
                }
            }
        }

        // ─────────────────────────────────────────
        //  STAGE 8 - Build → Trivy Image Scan → Push (commented)
        //  Order per service: build → scan → push
        // ─────────────────────────────────────────
        stage('Build, Scan & Push Images') {
            parallel {
                stage('Backend') {
                    steps {
                        script {
                            def tag = env.IMAGE_TAG
                            // Step 1: Build
                            sh """
                                docker build \
                                    --label "build.number=${tag}" \
                                    --label "git.branch=main" \
                                    --label "built.by=jenkins" \
                                    -t ${DOCKERHUB_USER}/food-backend:${tag} \
                                    ./backend
                            """
                            // Step 2: Scan built image
                            sh "trivy image --exit-code 0 --severity HIGH,CRITICAL ${DOCKERHUB_USER}/food-backend:${tag} > trivy-backend-image.txt 2>&1"
                            archiveArtifacts artifacts: 'trivy-backend-image.txt'
                            // Step 3: Push (commented for testing)
                            sh "docker push ${DOCKERHUB_USER}/food-backend:${tag}"
                        }
                    }
                }
                stage('Frontend') {
                    steps {
                        script {
                            def tag = env.IMAGE_TAG
                            // Step 1: Build
                            sh """
                                docker build \
                                    --build-arg VITE_BACKEND_URL=/api \
                                    --label "build.number=${tag}" \
                                    --label "git.branch=main" \
                                    --label "built.by=jenkins" \
                                    -t ${DOCKERHUB_USER}/food-frontend:${tag} \
                                    ./frontend
                            """
                            // Step 2: Scan built image
                            sh "trivy image --exit-code 0 --severity HIGH,CRITICAL ${DOCKERHUB_USER}/food-frontend:${tag} > trivy-frontend-image.txt 2>&1"
                            archiveArtifacts artifacts: 'trivy-frontend-image.txt'
                            // Step 3: Push (commented for testing)
                            sh "docker push ${DOCKERHUB_USER}/food-frontend:${tag}"
                        }
                    }
                }
                stage('Admin') {
                    steps {
                        script {
                            def tag = env.IMAGE_TAG
                            // Step 1: Build
                            sh """
                                docker build \
                                    --build-arg VITE_BACKEND_URL=/api \
                                    --label "build.number=${tag}" \
                                    --label "git.branch=main" \
                                    --label "built.by=jenkins" \
                                    -t ${DOCKERHUB_USER}/food-admin:${tag} \
                                    ./admin
                            """
                            // Step 2: Scan built image
                            sh "trivy image --exit-code 0 --severity HIGH,CRITICAL ${DOCKERHUB_USER}/food-admin:${tag} > trivy-admin-image.txt 2>&1"
                            archiveArtifacts artifacts: 'trivy-admin-image.txt'
                            // Step 3: Push (commented for testing)
                            sh "docker push ${DOCKERHUB_USER}/food-admin:${tag}"
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────
        //  STAGE 9 - Update K8s Manifests
        // ─────────────────────────────────────────
        stage('Update K8s Manifests') {
            steps {
                script {
                    def tag = env.IMAGE_TAG
                    withCredentials([usernamePassword(
                        credentialsId: 'github-credentials',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_PASS'
                    )]) {
                        sh """
                            rm -rf ${K8S_REPO_NAME}
                            git clone https://\$GIT_USER:\$GIT_PASS@github.com/your_username/your_repo_name.git

                            cd ${K8S_REPO_NAME}

                            sed -i "s|image: ${DOCKERHUB_USER}/food-backend:.*|image: ${DOCKERHUB_USER}/food-backend:${tag}|g" backend-deployment.yaml
                            sed -i "s|image: ${DOCKERHUB_USER}/food-frontend:.*|image: ${DOCKERHUB_USER}/food-frontend:${tag}|g" frontend-deployment.yaml
                            sed -i "s|image: ${DOCKERHUB_USER}/food-admin:.*|image: ${DOCKERHUB_USER}/food-admin:${tag}|g" admin-deployment.yaml

                            git config user.email "jenkins@ci.com"
                            git config user.name "Jenkins"
                            git add .

                            if git diff --cached --quiet; then
                                echo "No changes to commit"
                            else
                                git commit -m "[Jenkins] Deploy build ${tag} - \$(date -u '+%Y-%m-%d %H:%M UTC')"
                                git push https://\$GIT_USER:\$GIT_PASS@github.com/your_username/your_repo_name.git main
                            fi
                        """
                    }
                }
            }
        }

    }

    // ─────────────────────────────────────────
    //  POST ACTIONS
    // ─────────────────────────────────────────
    post {
        always {
            sh 'docker logout || true'
            sh 'docker image prune -f || true'
        }
        success {
            script {
                def tag = env.IMAGE_TAG ?: 'unknown'
                echo """
                Build SUCCESS
                ─────────────────────────────
                Image Tag : ${tag}
                ─────────────────────────────
                Images built & scanned:
                  ${DOCKERHUB_USER}/food-backend:${tag}
                  ${DOCKERHUB_USER}/food-frontend:${tag}
                  ${DOCKERHUB_USER}/food-admin:${tag}
                ─────────────────────────────
                NOTE: Pushes are commented out (testing mode)
                Uncomment push lines in Stage 8 when ready
                ─────────────────────────────
                """
            }
        }
        failure {
            script {
                def tag = env.IMAGE_TAG ?: 'not-set'
                echo """
                Build FAILED
                ─────────────────────────────
                Build Number : ${BUILD_NUMBER}
                Image Tag    : ${tag}
                ─────────────────────────────
                Check logs above for the failed stage
                ─────────────────────────────
                """
            }
        }
    }
}