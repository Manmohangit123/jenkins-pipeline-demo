pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 60, unit: 'MINUTES')
  }

  environment {
    AWS_DEFAULT_REGION = 'eu-north-1'
    PLAN_ROLE  = 'arn:aws:iam::201333676737:role/jenkins-plan-role'
    APPLY_ROLE = 'arn:aws:iam::201333676737:role/jenkins-apply-role'
    TF_IN_AUTOMATION = 'true'
  }

  stages {
    stage('Python lint and test') {
      steps {
        sh '''
          python3 -m venv .venv
          . .venv/bin/activate
          pip install --quiet pytest flake8
          flake8 --exclude=.venv,.terraform .
          pytest
        '''
      }
    }

    stage('Terraform format check') {
      steps {
        sh 'terraform fmt -check'
      }
    }

    stage('Terraform init, validate, plan') {
      steps {
        script {
          withEnv(awsEnv(env.PLAN_ROLE)) {
            sh '''
              terraform init -input=false
              terraform validate
              terraform plan -input=false -no-color > plan.txt || { cat plan.txt; exit 1; }
              cat plan.txt
            '''
          }
        }
      }
    }

    stage('Comment plan on PR') {
      when { changeRequest() }
      steps {
        withCredentials([usernamePassword(credentialsId: 'github-pat', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
          sh '''
            head -c 60000 plan.txt > plan_short.txt
            jq -n --rawfile plan plan_short.txt '{body: ("### Terraform Plan (Jenkins)\\n```\\n" + $plan + "\\n```")}' > comment.json
            curl -sS --fail-with-body -X POST -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" https://api.github.com/repos/Manmohangit123/jenkins-pipeline-demo/issues/$CHANGE_ID/comments -d @comment.json
          '''
        }
      }
    }

    stage('Approval') {
      when { branch 'main' }
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          input message: 'Apply this plan to AWS? (read the plan in the console log first)', ok: 'Approve and apply'
        }
      }
    }

    stage('Apply') {
      when { branch 'main' }
      steps {
        script {
          withEnv(awsEnv(env.APPLY_ROLE)) {
            sh '''
              terraform init -input=false
              terraform plan -input=false -out=tfplan
              terraform apply -input=false tfplan
            '''
          }
        }
      }
    }
  }

  post {
    always { sh 'rm -f tfplan' }
    failure { echo 'Pipeline failed. Open the red stage and read its log.' }
  }
}

// Reads the starter keys from Jenkins credentials, assumes the role,
// and returns the temporary credentials (valid about 1 hour) as env vars
def awsEnv(String roleArn) {
  def raw = ''
  withCredentials([usernamePassword(credentialsId: 'aws-base-keys', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
    raw = sh(
      script: "aws sts assume-role --role-arn ${roleArn} --role-session-name jenkins-${env.BUILD_NUMBER} --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text",
      returnStdout: true
    ).trim()
  }
  def out = raw.split('\\s+')
  return [
    "AWS_ACCESS_KEY_ID=${out[0]}",
    "AWS_SECRET_ACCESS_KEY=${out[1]}",
    "AWS_SESSION_TOKEN=${out[2]}"
  ]
}
