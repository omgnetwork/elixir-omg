podTemplate(
    label: 'omisego',
    containers: [
        containerTemplate(
            name: 'jnlp',
            image: 'gcr.io/omise-go/jenkins-slave-elixir:latest',
            args: '${computer.jnlpmac} ${computer.name}',
            alwaysPullImage: true
        ),
    ],
) {
    node('omisego') {
        stage('Checkout') {
            checkout scm
        }

        stage('Build') {
            sh("mix do local.hex --force, local.rebar --force")
            sh("apt-get install -y libgmp3-dev")
            withEnv(["MIX_ENV=test"]) {
                sh("mix do deps.get, deps.compile, compile")
            }
        }

        stage('Build Geth temp') {
          withEnv(["GETHPATH=go_ethereum","GETH_VERSION=release/1.7" ]){
            sh("\
            # NOTE: getting from ppa doesn't work, so building from source\
            RUN set -xe && \
                mkdir -p ${GETHPATH} && \
                cd ${GETHPATH} && \
                git init && \
                git remote add origin https://github.com/ethereum/go-ethereum && \
                git fetch --depth 1 origin ${GETH_VERSION} && \
                git checkout FETCH_HEAD && \
                make geth && \
                cd build/bin && \
                export PATH=$PATH:${PWD} && \
                geth version")
          }
        }

        stage('Test') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix coveralls.html --umbrella")
            }
        }

        stage('Lint') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix credo")
            }
        }

        stage('Cleanbuild') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix compile --force --warnings-as-errors")
            }
        }
/*
        stage('Dialyze') {
            sh("mix dialyzer --halt-exit-status")
        }
*/
    }
}
