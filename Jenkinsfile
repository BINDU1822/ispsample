pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        AWS_CREDENTIALS = credentials('aws-credentials')
        PATH = "${env.HOME}/bin:${env.PATH}"
    }

    parameters {
        booleanParam(name: 'DRY_RUN', defaultValue: true, description: 'Dry run to see what would be deleted')

    }

    triggers {
        // Schedule to run at midnight on the 1st of every month
        cron('0 0 1 * *')
    }

    stages {
        stage('Install or Update AWS CLI') {
            steps {
                sh '''
                if command -v aws &> /dev/null
                then
                    echo "AWS CLI found, updating..."
                    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                    unzip -o awscliv2.zip
                    ./aws/install --install-dir $HOME/aws-cli --bin-dir $HOME/bin --update
                    export PATH=$HOME/bin:$PATH
                else
                    echo "AWS CLI not found, installing..."
                    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                    unzip -o awscliv2.zip
                    ./aws/install --install-dir $HOME/aws-cli --bin-dir $HOME/bin
                    export PATH=$HOME/bin:$PATH
                fi
                '''
                // Ensure the new path is used in subsequent steps
                sh 'export PATH=$HOME/bin:$PATH'
            }
        }
        stage('AWS Credentials') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY' ]]) {
                    sh '''
                    export PATH=$HOME/bin:$PATH
                    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                    aws configure set region $AWS_REGION
                    aws configure list
                    '''
                }
            }
        }
        stage('Clean Old AMIs') {
            steps {
                script {
                    def dryRunFlag = params.DRY_RUN ? 'true' : 'false'
                    sh """
                    chmod +x ./remove_old_amis.sh
                    DRY_RUN=${dryRunFlag} ./remove_old_amis.sh
                    """
                }
            }
        }
    }
}
