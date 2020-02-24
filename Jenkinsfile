//@Library(value='utilsLib', changelog=false) _


def pipelineConfig=[
  // A. ENV-SPECIFIC VALUES (MAY DIFFER ON OTHER JENKINS/KUBERNETES/NEXUS) -------------------
  
  branchesKubernetesNamespaces: [
    //'demo': 'r10-app-dev'
    //,'release-.+: 'r10-app-test'
  ],
  npmRegistryUrl: 'https://nexus.javelin.vodafone.com/repository/npm-app-framework-group/',
  npmPrivateRegistryUrl: 'https://nexus.javelin.vodafone.com/repository/npm-app-framework-private/',
  dockerRegistry: 'docker-r10.javelin.vodafone.com',
  dockerOrg: 'r10_core_app',
  //The same user will be used for the npm and docker registries hosted on Nexus
  npmRegistryCredentialsId: 'nexusBase64Encoded',
  dockerRegistryCredentialsId: 'nexus',
  kubernetesCredentialsId: 'devKubernetesConfig',

  // B. FIXED VALUES -------------------------------------------------------------------------
  
  //Repo name must be lowercase
  helmChartDir: 'helmCharts/vfes-web',
  //Which values.yaml to use to lint the Helm chart. The path is relative to the Helm chart's dir
  helmChartTestFileName: 'values-test.yaml',
  
  // C. CALCULATED VALUES -------------------------------------------------------------------- 
  dockerImagesTag: env.BUILD_NUMBER,
  helmChartVersion: env.BUILD_NUMBER
]
def _buildDockerProject(def projectName, def pipelineConfig) {
  projectAttributes=_getDockerProjectAttributes(projectName, pipelineConfig)
  
  echo "Building Docker file for project '${projectName}'..."
  //Create .npmrc file with connection details and credentials for npm registries
  
  // Get base64 encoded "user:password"
  withCredentials([string(credentialsId: pipelineConfig.npmRegistryCredentialsId, variable: 'NPM_AUTH')]) {
    def npmConfig="""
#Default group registry to download packages
registry=${pipelineConfig.npmRegistryUrl}
always-auth=true
_auth=${env.NPM_AUTH}

#Private registry to download packages (use additional "--scope=@privateRegistry" argument in the npm commands)
@privateRegistry:registry=${pipelineConfig.npmPrivateRegistryUrl}
//DOMAIN/FEED/:always-auth=true
//DOMAIN/FEED/:_auth=${env.NPM_AUTH}
"""
    
    writeFile(file: ".npmrc", text: npmConfig)
  }
  
  //Build the docker image
  try {
    sh "npm i"
    sh "export NG_CLI_ANALYTICS=ci"
    sh "npm install -g @angular/cli"
    sh "ng build  --env=uat  --aot --sourcemap=false"
    sh "docker build -t ${projectAttributes.dockerImage} ."
  } finally {
    //Do some cleanup
    sh "rm -f .npmrc"
    sh "rm -r node_modules/@angular/cli/node_modules/webpack"
  }
}

def _publishDockerProjectArtifacts(def projectName, def pipelineConfig) {
  assert projectName
  
  projectAttributes=_getDockerProjectAttributes(projectName, pipelineConfig)
  
  //Push the docker image
  echo "Pushing Docker image for project '${projectName}'..."
  
  def tmpDockerPwdFile="${projectName}/tmpDocker"
  
  withCredentials([usernamePassword(credentialsId: pipelineConfig.dockerRegistryCredentialsId, usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASSWORD')]) {
    writeFile(file: tmpDockerPwdFile, text: env.DOCKER_PASSWORD)
    
    try {
      sh "cat ${tmpDockerPwdFile}|docker login -u ${env.DOCKER_USER} --password-stdin ${pipelineConfig.dockerRegistry} && docker push ${projectAttributes.dockerImage}"
    } finally {
    //Do some cleanup
      sh "rm -f ${tmpDockerPwdFile}"
    }
  }
}
def _getDockerProjectAttributes(def projectName, def pipelineConfig) {
  assert projectName
  
  attributes=[ dockerImageRepo: "${pipelineConfig.dockerOrg}/${projectName}" ]  
  attributes.dockerRegistryImageRepo="${pipelineConfig.dockerRegistry}/${attributes.dockerImageRepo}"
  attributes.dockerImage="${attributes.dockerRegistryImageRepo}:${pipelineConfig.dockerImagesTag}"
  
  echo "'${projectName}' docker attributes: ${attributes}"
  
  return attributes
}

def _getKubernetesNamespace(def pipelineConfig) {
  k8sNamespace=null
  
  pipelineConfig.branchesKubernetesNamespaces.any { branchPattern, branchNamespace ->
    if (env.BRANCH_NAME ==~ /${branchPattern}/) {
      k8sNamespace=branchNamespace
    }
  }
  
  return k8sNamespace
}

pipeline {
  agent { label 'slave' }
   
  options {
    disableConcurrentBuilds()
    timestamps()
    timeout(time: 1, unit: 'HOURS')
    preserveStashes(buildCount: 5)
    disableResume()
    //Skip the default checkout to clear the workspace first and then checkout in an "Initialize" stage.
    skipDefaultCheckout()
  }
  
  //parameters {}
  //environment {}
  
  stages {
    //Initialize the workspace
    stage('Checkout clean workspace') {
     steps {
        cleanWs()
        //checkout scm
      }
    }
  stage('Checkout') {
    steps {
      checkout([$class: 'GitSCM', branches: [[name: '${BRANCH}']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: 'VFES Github API token', url: '${REPO}']]])
      }
    }
  
    //Build artifacts
    stage('Prepare Helm chart') {
      steps {
        dir(pipelineConfig.helmChartDir) {
           //Replace values in the Helm chart
          echo 'Preparing Helm chart...'
          
          sh "sed -i \"s@ dockerRegistry:.*@ dockerRegistry: ${pipelineConfig.dockerRegistry}@g\" values.yaml"
          sh "sed -i \"s@ dockerOrg:.*@ dockerOrg: ${pipelineConfig.dockerOrg}@g\" values.yaml"
          sh "sed -i \"s@ tag:.*@ tag: ${pipelineConfig.dockerImagesTag}@g\" values.yaml"
          sh "sed -i \"s@version:.*@version: ${pipelineConfig.helmChartVersion}@g\" Chart.yaml"
          
          //Test the Helm chart
          echo 'Validating the Helm chart...'
          sh "helm lint --values ${pipelineConfig.helmChartTestFileName} ."
        }
      }
    }
    
    stage('Build vfes-Web') {
      steps {
        nodejs(nodeJSInstallationName: 'nodejs') {
           _buildDockerProject('vfes-Web', pipelineConfig)
        }
      }
    }
    
    //Publish artifacts
    stage('Publish vfes-Web') {
      steps {
        //_publishDockerProjectArtifacts('vfes-Web', pipelineConfig)
        echo 'skip for now'
      }
    }
    
    //Deploy Helm chart - only when a namespace is defined for the current branch
    stage('Deploy Kubernetes') {
      when {
          expression { return false }
      }
      //when {
        //expression { return _getKubernetesNamespace(pipelineConfig) != null }
      //}
      steps {
        //Install/update the Helm chart
        echo "Deploying Helm chart at '${pipelineConfig.helmChartDir}'..."
        
        script {
          def k8sNamespace=_getKubernetesNamespace(pipelineConfig)
          assert k8sNamespace!=null
          
          withCredentials([file(credentialsId: pipelineConfig.kubernetesCredentialsId, variable: 'KUBECONFIG')]) {
            sh "helm upgrade helm-${k8sNamespace} --namespace ${k8sNamespace} --install ${pipelineConfig.helmChartDir} --atomic --force --values ${pipelineConfig.helmChartDir}/${k8sNamespace}_values.yaml"
          }
        }
      }
    }
  }
   
  post {
    always {
      script {
        //Send slack notification
        def color=null
        
        if (currentBuild.currentResult == 'SUCCESS') {
          color='#00FF00'
        } else if (currentBuild.currentResult == 'FAILURE') {
          color='#FF0000'
        } else {
          color='#FFFF00'
        }
        /* Disabled the slack notifications because the Jenkins CI app is disabled on Vodafone's Slack
        catchError(catchInterruptions: false, stageResult: 'SUCCESS', buildResult: 'SUCCESS') {
          //The "channel" argument is not set, the default channel is used frin the Global Jenkins Configuration
          slackSend(color: color, message: "Status: ${currentBuild.currentResult}, Build: ${env.BUILD_URL}")
        }
        */
      }
    }
  }
}
