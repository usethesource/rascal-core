node {
    try {
        stage('Clone'){
            checkout scm 
        }

        withMaven(maven: 'M3', options: [artifactsPublisher(disabled: true)] ) {
            stage('Build and Test'){
                sh "mvn clean install"
            }

            stage('Deploy'){
                sh "mvn deploy"
            }
        }
        if (currentBuild.previousBuild.result == "FAILURE") { 
            slackSend (color: '#5cb85c',  message: "BUILD BACK TO NORMAL: <${env.BUILD_URL}|${env.JOB_NAME} [${env.BUILD_NUMBER}]>")
        }

        build job: '../../cwi-swat/rascal-core-plugin/master', wait: false

    } catch (e) {
        slackSend (color: '#d9534f', message: "FAILED: <${env.BUILD_URL}|${env.JOB_NAME} [${env.BUILD_NUMBER}]>")
        throw e
    }
}
