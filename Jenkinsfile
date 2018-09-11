pipeline {
    agent none
    environment {
        vmwarecreds = credentials('admincreds')
        domainadmin = credentials('domainadmin')
        slackChannelurl = credentials('SlackURL')
    }
    parameters {
        string(name: 'imagetype', defaultValue: '', description: 'Image Type')
        string(name: 'responseurl', defaultValue: '', description: 'Slack Response URL')
        string(name: 'email', defaultValue: '', description: 'Email of user')
        string(name: 'whosubmitted', defaultValue: '', description: 'User who submitted')
    }
    stages {
        stage('Build MDT Image') {
            agent {label 'MDT'} 
            steps {
                powershell '& "D:\\MDTProduction\\ServerScripts\\BuildVM.ps1"'
            }
        }
        stage('Upgrade Machine Catalog') {
            agent {label 'Citrix' } 
            steps {
                powershell '& "C:\\Scripts\\UpgradeMC.ps1"'
            }
        }
        stage('Archive files') {
            agent {label 'MDT'} 
            steps {
                powershell ''' 
                move-item -path "D:\\MDTProduction\\TempArt\\*.json" -Destination $pwd
                '''
                archiveArtifacts artifacts: '*.json', fingerprint: true
            }
        }
        
    }
    post {
        success {
            node('MDT'){
                echo "Removing VM"
                powershell '& "D:\\MDTProduction\\ServerScripts\\RemoveVM.ps1"'
                slackSend color: 'good', message: "${env.JOB_NAME} has COMPLETED for job ${env.BUILD_NUMBER}! (<${env.BUILD_URL}|Open>)"
                echo "Cleaning out Directory"
                deleteDir()
            }
            node('Citrix'){
                echo "Cleaning out Directory"
                deleteDir()
            }
        }
        failure {
            slackSend color: 'danger', message: "${env.JOB_NAME} has FAILED! (<${env.BUILD_URL}|Open>)"
        }
    }
}